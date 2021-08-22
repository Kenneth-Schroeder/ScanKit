//
//  RawDataCollector.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 22.08.21.
//

import Foundation
import ARKit
//import Progress

class RawDataCollector: CollectionWriterDelegate {
    var frameCount = 0
    var writesQueued = 0
    var writesFinished = 0
    let EXPECTED_FPS = 60
    let SEQUENCE_LENGTH_SEC = 10
    let uploadQueue = DispatchQueue(label: "upload-queue", qos: .userInitiated, attributes: .concurrent)
    
    var videoWriter: VideoWriter?
    var depthWriter: PixelBufferCollectionWriter?
    var confidenceWriter: PixelBufferCollectionWriter?
    var frameCollectionWriter: FrameCollectionWriter?
    
    var rgbMeta = SequenceMetaInfo(filePrefix: "rgb", fileExtension: "mov", expectedFps: 60)
    var depthMeta = SequenceMetaInfo(filePrefix: "depth", fileExtension: "txt", expectedFps: 60)
    var confMeta = SequenceMetaInfo(filePrefix: "confidence", fileExtension: "txt", expectedFps: 60)
    var jsonMeta = SequenceMetaInfo(filePrefix: "frameCollection", fileExtension: "json", expectedFps: 60)
    
    func fileWritten() {
        writesFinished += 1

        if !ScanConfig.isRecording {
            updateProgress(with: Float(self.writesFinished)/Float(self.writesQueued))
        }
    }
    
    func collectDataOf(arFrame: ARFrame) {
        guard let url = ScanConfig.url else { return }
        if !ScanConfig.isRecording { return }
        
        let capturedImage = arFrame.capturedImage
        let depthBuffer = (arFrame.sceneDepth?.depthMap)!
        let confidenceBuffer = (arFrame.sceneDepth?.confidenceMap)!
        
        // initialize writers if they are reset
        
        if videoWriter == nil {
            let rgbResolution = CGSize(width: CVPixelBufferGetWidth(capturedImage), height: CVPixelBufferGetHeight(capturedImage))
            rgbMeta.setResolutionAndPath(resolution: rgbResolution, path: url)
            videoWriter = VideoWriter(delegate: self, sampleBuffer: capturedImage, metaInfo: rgbMeta)
        }
        
        if depthWriter == nil {
            let depthResolution = CGSize(width: CVPixelBufferGetWidth(depthBuffer), height: CVPixelBufferGetHeight(depthBuffer))
            depthMeta.setResolutionAndPath(resolution: depthResolution, path: url)
            depthWriter = PixelBufferCollectionWriter(delegate: self, sampleBuffer: depthBuffer, metaInfo: depthMeta)
        }
        
        if confidenceWriter == nil {
            let confResolution = CGSize(width: CVPixelBufferGetWidth(confidenceBuffer), height: CVPixelBufferGetHeight(confidenceBuffer))
            confMeta.setResolutionAndPath(resolution: confResolution, path: url)
            confidenceWriter = PixelBufferCollectionWriter(delegate: self, sampleBuffer: confidenceBuffer, metaInfo: confMeta)
        }
        
        guard let videoWriter = videoWriter,
              let depthWriter = depthWriter,
              let confidenceWriter = confidenceWriter,
              let frameCollectionWriter = frameCollectionWriter else {
            print("Skipping data collection, unable to unwrap writer optionals")
            return
        }
        
        // append new data to each writer
        
        if ScanConfig.saveRGBVideo {
            if !videoWriter.appendPixelBuffer(capturedImage) {
                print("WARNING: An RGB frame is missing in recording.")
            }
        }
        
        if ScanConfig.saveDepthVideo {
            if !depthWriter.appendBuffer(depthBuffer) {
                print("WARNING: A depth frame is missing in depth file.")
            }
        }
        
        if ScanConfig.saveConfidenceVideo {
            if !confidenceWriter.appendBuffer(confidenceBuffer) {
                print("WARNING: A confidence frame is missing in confidence file.")
            }
        }
        
        // build object that connects all the data just collected
        
        let frameInfo = FrameInfo(ofFrame: arFrame)
        frameInfo.setRGBFrame(FrameLocation(fileName: videoWriter.getLastWrittenTitle(), frameNumber: videoWriter.getLastWrittenFrame(), resolution: videoWriter.getResolution()))
        frameInfo.setDepthFrame(FrameLocation(fileName: depthWriter.getLastWrittenTitle(), frameNumber: depthWriter.getLastWrittenFrame(), resolution: depthWriter.getResolution()))
        frameInfo.setConfidenceFrame(FrameLocation(fileName: confidenceWriter.getLastWrittenTitle(), frameNumber: confidenceWriter.getLastWrittenFrame(), resolution: confidenceWriter.getResolution()))
        
        jsonMeta.setPath(path: url)
        
        if !frameCollectionWriter.appendInfo(obj: frameInfo, metaInfo: jsonMeta) {
            print("ATTENTION: A full frame collection wasn't written to disk.")
        }
        
        // write to file if sequence finished
        
        frameCount += 1

        if frameCount >= EXPECTED_FPS * SEQUENCE_LENGTH_SEC {
            writeBuffersToFile()
        }
    }
    
    func stopRecording() {
        writeBuffersToFile()
        showProgressRing()
    }
    
    private func writeBuffersToFile() {
        let dw = depthWriter!
        let vW = videoWriter!
        let cW = confidenceWriter!
        let fCW = frameCollectionWriter!
        writesQueued += [ScanConfig.saveRGBVideo, ScanConfig.saveDepthVideo, ScanConfig.saveConfidenceVideo,
                         ScanConfig.saveRGBVideo || ScanConfig.saveDepthVideo || ScanConfig.saveConfidenceVideo || ScanConfig.saveWorldMapInfo].filter{$0}.count

        uploadQueue.async {[self, dw, vW, cW, fCW] in
            print("writing...")
            
            if ScanConfig.saveRGBVideo {
                vW.writeBufferToFile()
            }
            if ScanConfig.saveDepthVideo {
                dw.writeBufferToFile()
            }
            if ScanConfig.saveConfidenceVideo {
                cW.writeBufferToFile()
            }
            if ScanConfig.saveRGBVideo || ScanConfig.saveDepthVideo || ScanConfig.saveConfidenceVideo || ScanConfig.saveWorldMapInfo {
                fCW.writeBufferToFile()
            }
        }
        frameCount = 0
        videoWriter = nil
        depthWriter = nil
        confidenceWriter = nil
        frameCollectionWriter = nil
    }
    
    // MARK: - Progress indicator
    
    /*func showProgressRing() {
        let ringParam: RingProgressorParameter = (.proportional, UIColor.green.withAlphaComponent(0.4), 100, 50)
        var labelParam: LabelProgressorParameter = DefaultLabelProgressorParameter
        labelParam.font = UIFont.systemFont(ofSize: 30, weight: UIFont.Weight.bold)
        labelParam.color = UIColor.white.withAlphaComponent(0.3)
        DispatchQueue.main.async {
            Prog.start(in: self.viewController.view, .blur(.regular), .ring(ringParam), .label(labelParam))
        }
    }
    
    func updateProgress(with value: Float) {
        DispatchQueue.main.async {
            Prog.update(value, in: self.viewController.view)
        }
        if value >= 1.0 || value.isNaN {
            usleep(600_000) // sleep mills to not break Prog
            DispatchQueue.main.async {
                Prog.end(in: self.viewController.view)
            }
        }
    } */
}
