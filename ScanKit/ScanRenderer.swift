//
//  RawDataRenderer.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 11.08.21.
//

import Foundation
import Metal
import MetalKit
import ARKit
import MetalPerformanceShaders

class ScanRenderer {
    let session: ARSession
    let device: MTLDevice
    let inFlightSemaphore = DispatchSemaphore(value: kMaxBuffersInFlight)
    var renderDestination: RenderDestinationProvider
    
    // Metal objects
    var commandQueue: MTLCommandQueue!
    var sharedUniformBuffer: MTLBuffer!
    var imagePlaneVertexBuffer: MTLBuffer!
    
    private lazy var unprojectUniforms: UnprojectUniforms = {
        var uniforms = UnprojectUniforms()
        uniforms.cameraResolution = cameraResolution
        return uniforms
    }()
    var unprojectUniformsBuffers = [MetalBuffer<UnprojectUniforms>]() // metadata for unprojecting particles
    
    private lazy var viewshedCloudUniforms: PointCloudUniforms = {
        var uniforms = PointCloudUniforms()
        uniforms.particleSize = 10
        uniforms.coloringMethod = depth
        uniforms.confidenceThreshold = Int32(0) // always show all points for viewshed
        // other attributes will be updated continuously
        return uniforms
    }()
    var viewshedCloudUniformsBuffers = [MetalBuffer<PointCloudUniforms>]() // metadata for rendering viewshed particles
    
    var viewshedParticlesBuffers = [MetalBuffer<ParticleUniforms>]() // contains actual point data
    
    var capturedImagePipelineState: MTLRenderPipelineState!
    var confidencePipelineState: MTLRenderPipelineState!
    var float1DTexturePipelineState: MTLRenderPipelineState!
    var particleBlendedPipelineState: MTLRenderPipelineState!
    var unprojectPipelineState: MTLRenderPipelineState!
    
    var capturedImageTextureY: CVMetalTexture?
    var capturedImageTextureCbCr: CVMetalTexture?
    var confidenceTexture: CVMetalTexture?
    var depthTexture: CVMetalTexture?
    private lazy var depthSobelTexture: MTLTexture = getEmptyMTLTexture(256, 192)! // texture of the depth sobel results
    private lazy var YSobelTexture: MTLTexture = getEmptyMTLTexture(Int(cameraResolution.x), Int(cameraResolution.y))! // texture of the Y image sobel
    
    var relaxedDepthState: MTLDepthStencilState!
    var fullDepthState: MTLDepthStencilState!
    
    // Captured image texture cache
    var capturedImageTextureCache: CVMetalTextureCache!
    
    // Used to determine _uniformBufferStride each frame.
    //   This is the current frame number modulo kMaxBuffersInFlight
    var inFlightBufferIndex: Int = 0
    
    // Offset within _sharedUniformBuffer to set for the current frame
    var sharedUniformBufferOffset: Int = 0
    
    // Addresses to write shared uniforms to each frame
    var sharedUniformBufferAddress: UnsafeMutableRawPointer!
    
    // The current viewport size
    var viewportSize: CGSize = CGSize()
    
    // Flag for viewport size changes
    var viewportSizeDidChange: Bool = false
    
    private var sampleFrame: ARFrame { session.currentFrame! }
    private lazy var cameraResolution: Float2 = Float2(Float(sampleFrame.camera.imageResolution.width), Float(sampleFrame.camera.imageResolution.height)) // used to create selection grid from numGridPoints
    private lazy var particlesManager: ParticlesManager = ParticlesManager(metalDevice: device, cameraResolution: cameraResolution) // BufferManager object, holding all particleBuffers and corresponding logic
    
    private lazy var rotateToARCamera: matrix_float4x4 = makeRotateToARCameraTransform(orientation: deviceOrientation)

    init(session: ARSession, metalDevice device: MTLDevice, renderDestination: RenderDestinationProvider) {
        self.session = session
        self.device = device
        self.renderDestination = renderDestination
        loadMetal()
    }
    
    func drawRectResized(size: CGSize) {
        viewportSize = size
        viewportSizeDidChange = true
    }
    
    func update() {
        // Wait to ensure only kMaxBuffersInFlight are getting processed by any stage in the Metal
        //   pipeline (App, Metal, Drivers, GPU, etc)
        let _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        guard let currentFrame = session.currentFrame else {
            inFlightSemaphore.signal()
            return
        }
        
        // Create a new command buffer for each renderpass to the current drawable
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            commandBuffer.label = "MyCommand"
            
            // Add completion handler which signal _inFlightSemaphore when Metal and the GPU has fully
            //   finished processing the commands we're encoding this frame.  This indicates when the
            //   dynamic buffers, that we're writing to this frame, will no longer be needed by Metal
            //   and the GPU.
            // Retain our CVMetalTextures for the duration of the rendering cycle. The MTLTextures
            //   we use from the CVMetalTextures are not valid unless their parent CVMetalTextures
            //   are retained. Since we may release our CVMetalTexture ivars during the rendering
            //   cycle, we must retain them separately here.
            var textures = [capturedImageTextureY, capturedImageTextureCbCr, depthTexture, confidenceTexture]
            commandBuffer.addCompletedHandler{ [weak self] commandBuffer in
                if let strongSelf = self {
                    strongSelf.inFlightSemaphore.signal()
                }
                textures.removeAll()
            }
            
            updateRingBufferPointers()
            updateBufferState(frame: currentFrame)
            updateSobelTextures(commandBuffer: commandBuffer)
            
            if let renderPassDescriptor = renderDestination.currentRenderPassDescriptor,
               let currentDrawable = renderDestination.currentDrawable,
               let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                
                renderEncoder.label = "MyRenderEncoder"
                
                updateViewshed(frame: currentFrame, renderEncoder: renderEncoder)
                drawUnderlay(renderEncoder: renderEncoder)
                if ScanConfig.viewshedActive {
                    drawViewshed(renderEncoder: renderEncoder)
                }
                
                // We're done encoding commands
                renderEncoder.endEncoding()
                
                // Schedule a present once the framebuffer is complete using the current drawable
                commandBuffer.present(currentDrawable)
            }
            
            // Finalize rendering here & push the command buffer to the GPU
            commandBuffer.commit()
        }
    }
}

// MARK: - Drawing Functions

private extension ScanRenderer {
    
    func drawUnderlay(renderEncoder: MTLRenderCommandEncoder) {
        switch ScanConfig.underlayIndex {
        case 1:
            drawCapturedImage(renderEncoder: renderEncoder)
            break
        case 2:
            draw1DFloatTexture(renderEncoder: renderEncoder, scaleFactor: 1/10)
            break
        case 3:
            drawConfidenceTexture(renderEncoder: renderEncoder)
            break
        default:
            break
        }
    }
    
    func drawCapturedImage(renderEncoder: MTLRenderCommandEncoder) {
        guard let textureY = capturedImageTextureY, let textureCbCr = capturedImageTextureCbCr else {
            return
        }
        
        // Push a debug group allowing us to identify render commands in the GPU Frame Capture tool
        renderEncoder.pushDebugGroup("DrawCapturedImage")
        
        // Set render command encoder state
        renderEncoder.setCullMode(.none)
        renderEncoder.setRenderPipelineState(capturedImagePipelineState)
        renderEncoder.setDepthStencilState(relaxedDepthState)
        
        // Set mesh's vertex buffers
        renderEncoder.setVertexBuffer(imagePlaneVertexBuffer, offset: 0, index: Int(kUnderlayVertexDescriptors.rawValue))
        
        // Set any textures read/sampled from our render pipeline
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(textureY), index: Int(kTextureY.rawValue))
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(textureCbCr), index: Int(kTextureCbCr.rawValue))
        
        // Draw each submesh of our mesh
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        
        renderEncoder.popDebugGroup()
    }
    
    func draw1DFloatTexture(renderEncoder: MTLRenderCommandEncoder, scaleFactor: Float) {
        guard let depthTex = depthTexture else {
            return
        }
        var f: Float = scaleFactor
        
        renderEncoder.pushDebugGroup("DrawDepthTexture")
        
        renderEncoder.setCullMode(.none)
        renderEncoder.setRenderPipelineState(float1DTexturePipelineState)
        renderEncoder.setDepthStencilState(relaxedDepthState)
        
        renderEncoder.setVertexBuffer(imagePlaneVertexBuffer, offset: 0, index: Int(kUnderlayVertexDescriptors.rawValue))
        renderEncoder.setFragmentBytes(&f, length: MemoryLayout.size(ofValue: scaleFactor), index: 0)
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(depthTex), index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        
        renderEncoder.popDebugGroup()
    }
    
    func drawConfidenceTexture(renderEncoder: MTLRenderCommandEncoder) {
        guard let confTex = confidenceTexture else {
            return
        }
        
        renderEncoder.pushDebugGroup("DrawConfidenceTexture")
        
        renderEncoder.setCullMode(.none)
        renderEncoder.setRenderPipelineState(confidencePipelineState)
        renderEncoder.setDepthStencilState(relaxedDepthState)
        
        renderEncoder.setVertexBuffer(imagePlaneVertexBuffer, offset: 0, index: Int(kUnderlayVertexDescriptors.rawValue))
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(confTex), index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        
        renderEncoder.popDebugGroup()
    }
    
    func drawViewshed(renderEncoder: MTLRenderCommandEncoder) {
        var showByConfidence:Bool = false // show all points
        var alphaFactor:Float = 0.6
        var fakeTimestamp = 0
        
        renderEncoder.pushDebugGroup("DrawViewshed")
        
        renderEncoder.setCullMode(.none)
        renderEncoder.setRenderPipelineState(particleBlendedPipelineState)
        renderEncoder.setDepthStencilState(fullDepthState)
        
        renderEncoder.setVertexBuffer(viewshedCloudUniformsBuffers[inFlightBufferIndex])
        renderEncoder.setVertexBuffer(viewshedParticlesBuffers[inFlightBufferIndex], atCustomIndex: Int(kParticleUniforms.rawValue))
        renderEncoder.setVertexBytes(&showByConfidence, length: MemoryLayout.size(ofValue: showByConfidence), index: Int(kFreeBufferIndex.rawValue)+0)
        renderEncoder.setVertexBytes(&alphaFactor, length: MemoryLayout.size(ofValue: alphaFactor), index: Int(kFreeBufferIndex.rawValue)+1)
        renderEncoder.setVertexBytes(&fakeTimestamp, length: MemoryLayout.size(ofValue: fakeTimestamp), index: Int(kFreeBufferIndex.rawValue)+2)
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: ScanConfig.numGridPoints)
        
        renderEncoder.popDebugGroup()
    }
}

// MARK: - Update Functions

private extension ScanRenderer {
    
    func updateRingBufferPointers() {
        // Update the location(s) to which we'll write to in our dynamically changing Metal buffers for
        //   the current frame (i.e. update our slot in the ring buffer used for the current frame)
        
        inFlightBufferIndex = (inFlightBufferIndex + 1) % kMaxBuffersInFlight
        sharedUniformBufferOffset = kAlignedSharedUniformsSize * inFlightBufferIndex
        sharedUniformBufferAddress = sharedUniformBuffer.contents().advanced(by: sharedUniformBufferOffset)
    }
    
    func updateBufferState(frame: ARFrame) {
        updateSharedUniforms(frame: frame)
        updateCapturedImageTextures(frame: frame)
        updateDepthConfidenceTextures(frame: frame)
        
        if viewportSizeDidChange {
            viewportSizeDidChange = false
            updateImagePlane(frame: frame)
        }
    }
    
    func updateSharedUniforms(frame: ARFrame) {
        // Update the shared uniforms of the frame
        
        let sharedUniforms = sharedUniformBufferAddress.assumingMemoryBound(to: SharedUniforms.self)
        
        let camera = frame.camera
        let arCamViewMatrix = camera.viewMatrix(for: deviceOrientation)
        let perspectiveProjectionMatrix = camera.projectionMatrix(for: deviceOrientation, viewportSize: viewportSize, zNear: 0.001, zFar: 10)
        
        let viewMatrix = arCamViewMatrix
        let projectionMatrix = perspectiveProjectionMatrix
        
        sharedUniforms.pointee.viewMatrix = viewMatrix
        sharedUniforms.pointee.projectionMatrix = projectionMatrix
        
        unprojectUniforms.localToWorld = arCamViewMatrix.inverse * rotateToARCamera
        unprojectUniforms.cameraIntrinsicsInversed = camera.intrinsics.inverse
        unprojectUniformsBuffers[inFlightBufferIndex][0] = unprojectUniforms
        
        viewshedCloudUniforms.viewProjectionMatrix = projectionMatrix * viewMatrix
        viewshedCloudUniformsBuffers[inFlightBufferIndex][0] = viewshedCloudUniforms

        /* TODO check empty project if i can use this for particle rendering
        // Set up lighting for the scene using the ambient intensity if provided
        var ambientIntensity: Float = 1.0
        
        if let lightEstimate = frame.lightEstimate {
            ambientIntensity = Float(lightEstimate.ambientIntensity) / 1000.0
        }
        
        let ambientLightColor: vector_float3 = vector3(0.5, 0.5, 0.5)
        uniforms.pointee.ambientLightColor = ambientLightColor * ambientIntensity
        
        var directionalLightDirection : vector_float3 = vector3(0.0, 0.0, -1.0)
        directionalLightDirection = simd_normalize(directionalLightDirection)
        uniforms.pointee.directionalLightDirection = directionalLightDirection
        
        let directionalLightColor: vector_float3 = vector3(0.6, 0.6, 0.6)
        uniforms.pointee.directionalLightColor = directionalLightColor * ambientIntensity
        
        uniforms.pointee.materialShininess = 30
         */
    }
    
    func updateCapturedImageTextures(frame: ARFrame) {
        // Create two textures (Y and CbCr) from the provided frame's captured image
        let pixelBuffer = frame.capturedImage
        
        if (CVPixelBufferGetPlaneCount(pixelBuffer) < 2) {
            return
        }
        
        capturedImageTextureY = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat:.r8Unorm, planeIndex:0)
        capturedImageTextureCbCr = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat:.rg8Unorm, planeIndex:1)
    }
    
    func updateDepthConfidenceTextures(frame: ARFrame) {
        guard let dMap = frame.sceneDepth?.depthMap,
              let cMap = frame.sceneDepth?.confidenceMap else { return }
        
        depthTexture = createTexture(fromPixelBuffer: dMap, pixelFormat:.r32Float, planeIndex:0)
        confidenceTexture = createTexture(fromPixelBuffer: cMap, pixelFormat: .r8Uint, planeIndex: 0)
    }
    
    func updateSobelTextures(commandBuffer: MTLCommandBuffer) {
        if let unwrappedCVMetalTex = depthTexture,
           let unwrappedMetalTex = CVMetalTextureGetTexture(unwrappedCVMetalTex) {
            let shader = MPSImageSobel(device: device) // MPSImageGaussianBlur(device: device, sigma: 5.0), MPSImageSobel(device: device)
            shader.encode(commandBuffer: commandBuffer, // calling encode probably creates another renderEncoder, which throws an error if a renderencoder was already created using the same commandBuffer - https://stackoverflow.com/questions/50141522/metal-makecomputecommandencoder-assertion-failure
                    sourceTexture: unwrappedMetalTex,
                    destinationTexture: depthSobelTexture)
        }
        
        if let unwrappedCVMetalTexY = capturedImageTextureY,
           let unwrappedMetalTexY = CVMetalTextureGetTexture(unwrappedCVMetalTexY) {
            let shader = MPSImageSobel(device: device)// MPSImageGaussianBlur(device: device, sigma: 5.0), MPSImageSobel(device: device)
            shader.encode(commandBuffer: commandBuffer, // calling encode probably creates another renderEncoder, which throws an error if a renderencoder was already created using the same commandBuffer - https://stackoverflow.com/questions/50141522/metal-makecomputecommandencoder-assertion-failure
                    sourceTexture: unwrappedMetalTexY,
                    destinationTexture: YSobelTexture)
        }
    }
    
    // genetate new points from image data
    private func updateViewshed(frame: ARFrame, renderEncoder: MTLRenderCommandEncoder) {
        var sobelConfig: simd_float4 = vector_float4(ScanConfig.sobelDepthThreshold, ScanConfig.sobelYThreshold, ScanConfig.sobelYEdgeSamplingRate, ScanConfig.sobelSurfaceSamplingRate)
        var depthThresholds: Float2 = vector_float2(ScanConfig.maxPointDepth, ScanConfig.minPointDepth)
        
        renderEncoder.pushDebugGroup("UpdateViewshed")
        
        renderEncoder.setDepthStencilState(relaxedDepthState)
        renderEncoder.setRenderPipelineState(unprojectPipelineState)
        renderEncoder.setVertexBuffer(unprojectUniformsBuffers[inFlightBufferIndex])
        renderEncoder.setVertexBuffer(viewshedParticlesBuffers[inFlightBufferIndex])
        renderEncoder.setVertexBuffer(particlesManager.gridPointsBuffer) // sampling grid points buffer
        renderEncoder.setVertexBytes(&sobelConfig, length: MemoryLayout.size(ofValue: sobelConfig), index: Int(kSobelThresholds.rawValue))
        renderEncoder.setVertexBytes(&depthThresholds, length: MemoryLayout.size(ofValue: depthThresholds), index: Int(kDepthThresholds.rawValue))
        renderEncoder.setVertexTexture(CVMetalTextureGetTexture(capturedImageTextureY!), index: Int(kTextureY.rawValue))
        renderEncoder.setVertexTexture(CVMetalTextureGetTexture(capturedImageTextureCbCr!), index: Int(kTextureCbCr.rawValue))
        renderEncoder.setVertexTexture(CVMetalTextureGetTexture(depthTexture!), index: Int(kTextureDepth.rawValue))
        renderEncoder.setVertexTexture(CVMetalTextureGetTexture(confidenceTexture!), index: Int(kTextureConfidence.rawValue))
        renderEncoder.setVertexTexture(depthSobelTexture, index: Int(kTextureDepthSobel.rawValue))
        renderEncoder.setVertexTexture(YSobelTexture, index: Int(kTextureYSobel.rawValue))
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particlesManager.gridSize)
        
        renderEncoder.popDebugGroup()
    }
    
    func updateImagePlane(frame: ARFrame) {
        // Update the texture coordinates of our image plane to aspect fill the viewport
        let displayToCameraTransform = frame.displayTransform(for: .portrait, viewportSize: viewportSize).inverted()

        let vertexData = imagePlaneVertexBuffer.contents().assumingMemoryBound(to: Float.self)
        for index in 0...3 {
            let textureCoordIndex = 4 * index + 2
            let textureCoord = CGPoint(x: CGFloat(kImagePlaneVertexData[textureCoordIndex]), y: CGFloat(kImagePlaneVertexData[textureCoordIndex + 1]))
            let transformedCoord = textureCoord.applying(displayToCameraTransform)
            vertexData[textureCoordIndex] = Float(transformedCoord.x)
            vertexData[textureCoordIndex + 1] = Float(transformedCoord.y)
        }
    }
}

// MARK: - Initialization Functions

private extension ScanRenderer {
    
    func createTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> CVMetalTexture? {
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
        
        var texture: CVMetalTexture? = nil
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, capturedImageTextureCache, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &texture)
        
        if status != kCVReturnSuccess {
            texture = nil
        }
        
        return texture
    }
    
    func loadMetal() {
        // Create and load our basic Metal state objects
        
        // Set the default formats needed to render
        renderDestination.depthStencilPixelFormat = .depth32Float_stencil8
        renderDestination.colorPixelFormat = .bgra8Unorm
        renderDestination.sampleCount = 1
        
        // Calculate our uniform buffer sizes. We allocate kMaxBuffersInFlight instances for uniform
        //   storage in a single buffer. This allows us to update uniforms in a ring (i.e. triple
        //   buffer the uniforms) so that the GPU reads from one slot in the ring wil the CPU writes
        //   to another.
        //   Also uniform storage must be aligned (to 256 bytes) to meet the requirements to be an
        //   argument in the constant address space of our shading functions.
        let sharedUniformBufferSize = kAlignedSharedUniformsSize * kMaxBuffersInFlight
        
        // Create and allocate our uniform buffer objects. Indicate shared storage so that both the
        //   CPU can access the buffer
        sharedUniformBuffer = device.makeBuffer(length: sharedUniformBufferSize, options: .storageModeShared)
        sharedUniformBuffer.label = "SharedUniformBuffer"
        
        // Create a vertex buffer with our image plane vertex data.
        let imagePlaneVertexDataCount = kImagePlaneVertexData.count * MemoryLayout<Float>.size
        imagePlaneVertexBuffer = device.makeBuffer(bytes: kImagePlaneVertexData, length: imagePlaneVertexDataCount, options: [])
        imagePlaneVertexBuffer.label = "ImagePlaneVertexBuffer"
        
        for _ in 0..<kMaxBuffersInFlight {
            viewshedParticlesBuffers.append(.init(device: device, count: ScanConfig.viewshedMaxCount, index: kViewshedParticleUniforms.rawValue))
            unprojectUniformsBuffers.append(.init(device: device, count: 1, index: kUnprojectUniforms.rawValue))
            viewshedCloudUniformsBuffers.append(.init(device: device, count: 1, index: kPointCloudUniforms.rawValue))
        }
        
        // Load all the shader files with a metal file extension in the project
        let defaultLibrary = device.makeDefaultLibrary()!
        
        makeCapturedImagePipelineState(library: defaultLibrary)
        makeConfidencePipelineState(library: defaultLibrary)
        makeFloat1DTexturePipelineState(library: defaultLibrary)
        makeParticleBlendedPipelineState(library: defaultLibrary)
        makeFilterUnprojectionPipelineState(library: defaultLibrary)
        makeRelaxedDepthState()
        makeFullDepthState()
        
        // Create captured image texture cache
        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
        capturedImageTextureCache = textureCache
        
        // Create the command queue
        commandQueue = device.makeCommandQueue()
    }
    
    func cameraToDisplayRotation(orientation: UIInterfaceOrientation) -> Int {
        switch orientation {
        case .landscapeLeft:
            return 180
        case .portrait:
            return 90
        case .portraitUpsideDown:
            return -90
        default:
            return 0
        }
    }
    
    func makeRotateToARCameraTransform(orientation: UIInterfaceOrientation) -> matrix_float4x4 {
        // flip to ARKit Camera's coordinate
        let flipYZ = matrix_float4x4(
            [1, 0, 0, 0],
            [0, -1, 0, 0],
            [0, 0, -1, 0],
            [0, 0, 0, 1] )

        let rotationAngle = Float(cameraToDisplayRotation(orientation: orientation)) * .degreesToRadian
        return flipYZ * matrix_float4x4(simd_quaternion(rotationAngle, Float3(0, 0, 1)))
    }
    
    func getEmptyMTLTexture(_ width: Int, _ height: Int) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: MTLPixelFormat.r32Float, // r32Float, rgba8Unorm
            width: width,
            height: height,
            mipmapped: false)
        
        textureDescriptor.usage = [.shaderRead, .shaderWrite] // refers to MTLTextureUsage.shaderRead (infered by context)
        
        return device.makeTexture(descriptor: textureDescriptor)
    }
    
    // MARK: Metal Pipeline States
    
    func underlayVertexDescriptors() -> MTLVertexDescriptor {
        // Create a vertex descriptor for our image plane vertex buffer
        let vertexDescriptor = MTLVertexDescriptor()
        
        // Positions
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = Int(kUnderlayVertexDescriptors.rawValue)
        
        // Texture coordinates
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = 8
        vertexDescriptor.attributes[1].bufferIndex = Int(kUnderlayVertexDescriptors.rawValue)
        
        // Buffer Layout
        vertexDescriptor.layouts[0].stride = 16
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        
        return vertexDescriptor
    }
    
    func makeCapturedImagePipelineState(library: MTLLibrary) {
        guard let capturedImageVertexFunction = library.makeFunction(name: "underlayImageVertex"),
              let capturedImageFragmentFunction = library.makeFunction(name: "capturedImageFragment") else {
            print("something went wrong while making captured image shader functions")
            return
        }
        
        // Create a pipeline state for rendering the captured image
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "MyCapturedImagePipeline"
        descriptor.sampleCount = renderDestination.sampleCount
        descriptor.vertexFunction = capturedImageVertexFunction
        descriptor.fragmentFunction = capturedImageFragmentFunction
        descriptor.vertexDescriptor = underlayVertexDescriptors()
        descriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        descriptor.stencilAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        
        do {
            try capturedImagePipelineState = device.makeRenderPipelineState(descriptor: descriptor)
        } catch let error {
            print("Failed to created captured image pipeline state, error \(error)")
        }
    }
    
    func makeConfidencePipelineState(library: MTLLibrary) {
        guard let vertexFunction = library.makeFunction(name: "underlayImageVertex"),
              let fragmentFunction = library.makeFunction(name: "confidenceFragment") else {
            print("something went wrong while making confidence shader functions")
            return
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.vertexDescriptor = underlayVertexDescriptors()
        descriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        descriptor.stencilAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        
        do {
            try confidencePipelineState = device.makeRenderPipelineState(descriptor: descriptor)
        } catch let error {
            print("Failed to created captured image pipeline state, error \(error)")
        }
    }
    
    func makeFloat1DTexturePipelineState(library: MTLLibrary) {
        guard let vertexFunction = library.makeFunction(name: "underlayImageVertex"),
            let fragmentFunction = library.makeFunction(name: "floatTexFragment") else {
                print("something went wrong while making float1DTexture shader functions")
                return
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.vertexDescriptor = underlayVertexDescriptors()
        descriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        descriptor.stencilAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        
        do {
            try float1DTexturePipelineState = device.makeRenderPipelineState(descriptor: descriptor)
        } catch let error {
            print("Failed to created captured image pipeline state, error \(error)")
        }
    }
    
    func makeParticleBlendedPipelineState(library: MTLLibrary) {
        guard let vertexFunction = library.makeFunction(name: "particleVertex"),
            let fragmentFunction = library.makeFunction(name: "particleFragment") else {
                print("something went wrong while making blended particle shader functions")
                return
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        descriptor.stencilAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        do {
            try particleBlendedPipelineState = device.makeRenderPipelineState(descriptor: descriptor)
        } catch let error {
            print("Failed to created captured image pipeline state, error \(error)")
        }
    }
    
    func makeFilterUnprojectionPipelineState(library: MTLLibrary) {
        
        guard let vertexFunction = library.makeFunction(name: "filterUnprojectVertex") else {
                print("something went wrong while making unprojection shader function")
                return
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.isRasterizationEnabled = false
        descriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        descriptor.stencilAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        
        
        do {
            try unprojectPipelineState = device.makeRenderPipelineState(descriptor: descriptor)
        } catch let error {
            print("Failed to created captured image pipeline state, error \(error)")
        }
    }
    
    // MARK: Metal Depth States
    
    func makeRelaxedDepthState() {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .always
        descriptor.isDepthWriteEnabled = false
        relaxedDepthState = device.makeDepthStencilState(descriptor: descriptor)
    }
    
    func makeFullDepthState() {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .lessEqual
        descriptor.isDepthWriteEnabled = true
        fullDepthState = device.makeDepthStencilState(descriptor: descriptor)
    }
}
