//
//  ParticlesManager.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 17.08.21.
//

import Foundation
import Metal

class ParticlesManager {
    private let device: MTLDevice
    private var cameraResolution: Float2
    
    lazy var gridPointsBuffer = MetalBuffer<Float2>(device: device, array: updateGridPoints(), index: kGridPoints.rawValue) // MetalBuffer containing the 'numGridPoints'-many point coordinates selected by CPU for GPU
    
    var visualParticlesBuffer = [MetalBuffer<ParticleUniforms>]()
    var visualBufferPointCount = [Int]()
    private var visualBufferIndex: Int = 0
    private var visualBuffersWriteAddress = [Int]()
    var visualPointCount: Int { visualBufferPointCount[visualBufferIndex] }
    var visualBuffer: MetalBuffer<ParticleUniforms> { visualParticlesBuffer[visualBufferIndex] }
    
    // DispatchQueues
    let copyQueue = DispatchQueue(label: "copy-queue", qos: .userInteractive) /// serial (!= sync), which means tasks in this queue are executed atomically, used for copying of selected points to mainBuffer
    let filterQueue = DispatchQueue(label: "filter-queue", qos: .userInitiated) /// serial (!= sync), which means tasks in this queue are executed atomically, used for filtering filled mainBuffers
    
    init(metalDevice device: MTLDevice, cameraResolution: Float2) {
        self.device = device
        self.cameraResolution = cameraResolution
        
        for _ in 0 ..< kMaxBuffersInFlight {
            visualParticlesBuffer.append(.init(device: device, count: ScanConfig.maxPointsPerVisualBuffer, index: kParticleUniforms.rawValue))
            visualBufferPointCount.append(0)
            visualBuffersWriteAddress.append(0)
        }
    }
    
    // Makes sample points on camera image, also precompute the anchor point for animation
    private func updateGridPoints() -> [Float2] {
        let gridArea = cameraResolution.x * cameraResolution.y
        let spacing = sqrt(gridArea / Float(ScanConfig.numGridPoints))
        let deltaX = Int(round(cameraResolution.x / spacing))
        let deltaY = Int(round(cameraResolution.y / spacing))
        
        var points = [Float2]()
        for gridY in 0 ..< deltaY {
            let alternatingOffsetX = Float(gridY % 2) * spacing / 2
            for gridX in 0 ..< deltaX {
                let cameraPoint = Float2(alternatingOffsetX + (Float(gridX) + 0.5) * spacing, (Float(gridY) + 0.5) * spacing)
                
                points.append(cameraPoint)
            }
        }
        
        return points
    }
    
    func updateSampleGrid() {
        gridPointsBuffer = MetalBuffer<Float2>(device: device,
                                               array: updateGridPoints(),
                                               index: kGridPoints.rawValue,
                                               options: [])
    }
    
    func processNewPoints(in buffer: MetalBuffer<ParticleUniforms>, signal semaphore: DispatchSemaphore) {
        let vBIdx = visualBufferIndex
        visualBufferIndex = (visualBufferIndex + 1) % kMaxBuffersInFlight
        if ScanConfig.isRecording {
            copyQueue.async {
                self.copySelectedPointsToVisualBuffer(fromViewshedBuffer: buffer, toVisualBufferIdx: vBIdx)
                semaphore.signal()
            }
        } else {
            semaphore.signal()
        }
    }
    
    func copySelectedPointsToVisualBuffer(fromViewshedBuffer buffer: MetalBuffer<ParticleUniforms>, toVisualBufferIdx vBIdx: Int) {
        for i in 0 ..< ScanConfig.numGridPoints { // sparseBufferSize
            if buffer[i].type.rawValue <= 1 && Float.random(in: 0..<1) > 0.9 { // move those points from sparseBuffer to particlesBuffer
                visualParticlesBuffer[vBIdx][visualBuffersWriteAddress[vBIdx]] = buffer[i]
                visualBuffersWriteAddress[vBIdx] = (visualBuffersWriteAddress[vBIdx] + 1) % ScanConfig.maxPointsPerVisualBuffer // copy threads are protected by dispatchGroupCopyThread so that there is no interference with this line
                
                if(visualBuffersWriteAddress[vBIdx] + 1 == ScanConfig.maxPointsPerVisualBuffer) {
                    print("EXITED copy early to prevent overwrite of visual buffer front") // minimize concurrent accesses on the front of the metalbuffer
                    break
                }
            }
        }
        
        visualBufferPointCount[vBIdx] = min(visualBuffersWriteAddress[vBIdx] + 1, ScanConfig.maxPointsPerVisualBuffer) // update point count for current mainBuffer
    }
}
