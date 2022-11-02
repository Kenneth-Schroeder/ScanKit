//
//  ParticlesManager.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 17.08.21.
//

import Foundation
import Metal

enum BufferStage : Int {
    case ready = 0
    case expanding = 1
    case thinning = 2
    case writing = 3
}

class ParticlesManager {
    private let device: MTLDevice
    private var cameraResolution: Float2
    
    lazy var gridPointsBuffer = MetalBuffer<Float2>(device: device, array: updateGridPoints(), index: kGridPoints.rawValue) // MetalBuffer containing the 'numGridPoints'-many point coordinates selected by CPU for GPU
    
    var visualParticlesBuffer = ThreadSafeArray<MetalBuffer<ParticleUniforms>>()
    var visualBufferPointCount = ThreadSafeArray<Int>()
    private var visualBufferIndex: Int = 0
    private var visualBuffersWriteAddress = ThreadSafeArray<Int>()
    var visualPointCount: Int { visualBufferPointCount[visualBufferIndex] }
    
    var recordingParticlesBuffer = ThreadSafeArray<MetalBuffer<ParticleUniforms>>()
    var recordingBufferPointCount = ThreadSafeArray<Int>()
    private var recordingBufferIndex: Int = 0
    private var recordingBuffersWriteAddress = ThreadSafeArray<Int>()
    var recordingPointCount: Int { recordingBufferPointCount[recordingBufferIndex] }
    private var recordingBufferStage = ThreadSafeArray<BufferStage>()
    
    private var writesQueued = 0
    private var writesFinished = 0
    
    // DispatchQueues
    let copyQueue = DispatchQueue(label: "copy-queue", qos: .userInteractive) /// serial (!= sync), which means tasks in this queue are executed atomically, used for copying of selected points to mainBuffer
    let filterQueue = DispatchQueue(label: "filter-queue", qos: .userInitiated) /// serial (!= sync), which means tasks in this queue are executed atomically, used for filtering filled mainBuffers
    
    private var lasWriter = LASwriter_oc()
    
    init(metalDevice device: MTLDevice, cameraResolution: Float2) {
        self.device = device
        self.cameraResolution = cameraResolution
        
        for _ in 0 ..< kMaxBuffersInFlight {
            visualParticlesBuffer.append(.init(device: device, count: ScanConfig.maxPointsPerVisualBuffer, index: kParticleUniforms.rawValue))
            visualBufferPointCount.append(0)
            visualBuffersWriteAddress.append(0)
            
            recordingParticlesBuffer.append(.init(device: device, count: ScanConfig.maxPointsPerRecordingBuffer, index: kParticleUniforms.rawValue))
            recordingBufferPointCount.append(0)
            recordingBuffersWriteAddress.append(0)
            recordingBufferStage.append(.ready)
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
        let rBIdx = recordingBufferIndex
        visualBufferIndex = (visualBufferIndex + 1) % kMaxBuffersInFlight
        
        if recordingBufferStage[rBIdx] != .ready { // dont touch the current buffer, if it is not ready, frame is dropped in this case
            semaphore.signal()
            return
        }
        
        if ScanConfig.isRecording {
            recordingBufferStage[rBIdx] = .expanding // 'expanding' means it is copying from sparseBuffer
            copyQueue.async {
                self.copySelectedPoints(fromViewshedBuffer: buffer, toVisualBufferIdx: vBIdx, toRecordingBufferIdx: rBIdx)
                
                if self.recordingBufferPointCount[rBIdx] == ScanConfig.maxPointsPerRecordingBuffer {
                    self.recordingBufferStage[rBIdx] = .writing // 'writing' to disk
                    self.recordingBufferIndex = (self.recordingBufferIndex + 1) % kMaxBuffersInFlight // async, but protected by semaphore; TODO could search for next ready buffer alternatively
                    
                    DispatchQueue.global(qos: .userInitiated).async {
                        // here, bufferStages are especially important since they prevent reentering thinning and rescheduling writing to file while a buffer is already waiting to be written
                        self.saveBuffer(at: rBIdx, signal: semaphore)
                    }
                }
                else {
                    self.recordingBufferStage[rBIdx] = .ready
                    semaphore.signal()
                }
            }
        } else {
            semaphore.signal()
        }
    }
    
    func copySelectedPoints(fromViewshedBuffer buffer: MetalBuffer<ParticleUniforms>, toVisualBufferIdx vBIdx: Int, toRecordingBufferIdx rBIdx: Int) {
        var visualBufferWriting: Bool = true
        var recordingBufferWriting: Bool = true
        
        for i in 0 ..< ScanConfig.numGridPoints { // sparseBufferSize
            if visualBufferWriting && buffer[i].type.rawValue <= 1 && Float.random(in: 0..<1) > 0.9 { // move those points from sparseBuffer to particlesBuffer
                visualParticlesBuffer[vBIdx][visualBuffersWriteAddress[vBIdx]] = buffer[i]
                visualBuffersWriteAddress[vBIdx] = (visualBuffersWriteAddress[vBIdx] + 1) % ScanConfig.maxPointsPerVisualBuffer // copy threads are protected by dispatchGroupCopyThread so that there is no interference with this line
                
                if(visualBuffersWriteAddress[vBIdx] + 1 == ScanConfig.maxPointsPerVisualBuffer) {
                    print("EXITED copy early to prevent overwrite of visual buffer front") // minimize concurrent accesses on the front of the metalbuffer
                    visualBufferWriting = false
                }
            }
            
            if recordingBufferWriting && buffer[i].type.rawValue <= 1 {
                recordingParticlesBuffer[rBIdx][recordingBuffersWriteAddress[rBIdx]] = buffer[i]
                recordingBuffersWriteAddress[rBIdx] = (recordingBuffersWriteAddress[rBIdx] + 1) % ScanConfig.maxPointsPerRecordingBuffer // copy threads are protected by dispatchGroupCopyThread so that there is no interference with this line
                
                if(recordingBuffersWriteAddress[rBIdx] + 1 == ScanConfig.maxPointsPerRecordingBuffer) {
                    print("EXITED copy early to prevent overwrite of recording buffer front") // minimize concurrent accesses on the front of the metalbuffer TODO: no concurrent accesses on recording buffer!
                    recordingBufferWriting = false
                }
            }
            
            if !visualBufferWriting && !recordingBufferWriting {
                break
            }
        }
        
        visualBufferPointCount[vBIdx] = min(visualBuffersWriteAddress[vBIdx] + 1, ScanConfig.maxPointsPerVisualBuffer) // update point count
        recordingBufferPointCount[rBIdx] = min(recordingBuffersWriteAddress[rBIdx] + 1, ScanConfig.maxPointsPerRecordingBuffer) // update point count
    }
    
    func saveBuffer(at index: Int, signal semaphore: DispatchSemaphore? = nil, notify tracker: ProgressTracker? = nil) {
        if ScanConfig.savePointCloud {
            writesQueued += 1
            let _ = saveBufferLocallyAsLAS(index: index, signal: semaphore) // this function itself is called synchronously within this thread
            writesFinished += 1
        }
        if let t = tracker {
            if writesFinished >= writesQueued {
                t.notifyProgressPC(value: 1) // in case both 0
            } else {
                t.notifyProgressPC(value: Float(writesFinished) / Float(writesQueued))
            }
        }
        // reset statistics
        recordingBufferPointCount[index] = 0
        recordingBuffersWriteAddress[index] = 0 /// TODO: check if only resetting pointIndex is enough, which could be designed so that old points are not deleted immediately, but get overwritten slowly as the buffer fills back up (need to prevent triggering of filtering though)
        recordingBufferStage[index] = .ready
    }
    
    func saveRemainingBuffer(notify tracker: ProgressTracker?) {
        saveBuffer(at: recordingBufferIndex, notify: tracker)
    }
    
    func saveBufferLocallyAsLAS(index: Int, withJson: Bool = true, signal semaphore: DispatchSemaphore? = nil) -> [URL?] {
        var paths = [URL?]()
        guard let localURL = ScanConfig.url else { return [] }
        
        let localPath = localURL
        let lasPath : URL = localPath.appendingPathComponent("Buffer_\(index)_" + Date().string(format: "yyyy-MM-dd_HH_mm_ss") + ".las")
        paths.append(lasPath)
        
        if(recordingBufferPointCount[index] > 0){
            let pointCount = recordingBufferPointCount[index]
            var arr = [ParticleUniforms](repeating: ParticleUniforms(), count: pointCount)
            recordingParticlesBuffer[index].copyTo(&arr)
            
            if let sem = semaphore {
                sem.signal()
            }
            
            print("Beginning to write " + String(pointCount) + " points to file...")
            lasWriter.write_lasFile(&arr, ofSize: Int32(pointCount), toFileNamed: lasPath.relativePath)
            print("Finished writing a file!")
            
            return paths
        }
        
        return [nil]
    }
}
