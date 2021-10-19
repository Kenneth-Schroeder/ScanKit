//
//  RawDataCollector.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 22.08.21.
//

import Foundation
import ARKit

class RawDataCollector: CollectionWriterDelegate {
    private var vc: ScanVC
    var frameCount = 0
    var writesQueued = 0
    var writesFinished = 0
    let EXPECTED_FPS = 60
    let SEQUENCE_LENGTH_SEC = 10
    var wm_worked = 0
    var wm_failed = 0
    var progressTracker: ProgressTracker? = nil
    let uploadQueue = DispatchQueue(label: "upload-queue", qos: .userInitiated, attributes: .concurrent)
    
    let qrDetector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyLow])
    var detectedCodes: [QRCode] = []
    
    var videoWriter: VideoWriter?
    var depthWriter: PixelBufferCollectionWriter?
    var confidenceWriter: PixelBufferCollectionWriter?
    var frameCollectionWriter: FrameCollectionWriter?
    
    var rgbMeta = SequenceMetaInfo(filePrefix: "rgb", fileExtension: "mov", expectedFps: 60)
    var depthMeta = SequenceMetaInfo(filePrefix: "depth", fileExtension: "txt", expectedFps: 60)
    var confMeta = SequenceMetaInfo(filePrefix: "confidence", fileExtension: "txt", expectedFps: 60)
    var jsonMeta = SequenceMetaInfo(filePrefix: "frameCollection", fileExtension: "json", expectedFps: 60)
    
    init(viewController: ScanVC) {
        self.vc = viewController
    }
    
    func codeWasDetected(_ newCode: QRCode) -> Bool {
        for p in detectedCodes {
            if p.squaredDistanceTo(code: newCode) < 1 {
                return true
            }
        }
        return false
    }
    
    func fileWritten() {
        writesFinished += 1
        
        if !ScanConfig.isRecording,
           let pt = progressTracker {
            pt.notifyProgressRaw(value: Float(writesFinished) / Float(writesQueued))
        }
    }
    
    func collectDataOf(arFrame: ARFrame) {
        guard let url = ScanConfig.url else { return }
        
        let capturedImage = arFrame.capturedImage
        
        guard let depthBuffer = arFrame.sceneDepth?.depthMap,
              let confidenceBuffer = arFrame.sceneDepth?.confidenceMap else {
            print("Skipping data collection, unable to unwrap depth or confidence map optionals")
            return
        }
        
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
        
        if frameCollectionWriter == nil {
            jsonMeta.setPath(path: url)
            frameCollectionWriter = FrameCollectionWriter(delegate: self, metaInfo: jsonMeta)
        }
        
        guard let videoWriter = videoWriter,
              let depthWriter = depthWriter,
              let confidenceWriter = confidenceWriter,
              let frameCollectionWriter = frameCollectionWriter else {
            print("Skipping data collection, unable to unwrap writer optionals")
            return
        }
        
        if !ScanConfig.isRecording { return } // recording check down here so that writers are already initialized when starting recording
        
        if !vc.updateMemoryBarAskContinue() {
            vc.finishRecording()
            return
        }
        
        // detect QR Codes
        
        if ScanConfig.detectQRCodes && frameCount % 6 == 0 {
            let codes = qrDetector?.features(in: CIImage(cvPixelBuffer: capturedImage)) as? [CIQRCodeFeature]
            for code in codes ?? [] {
                let capturedCoordinateSys = CGSize(width: CVPixelBufferGetWidth(capturedImage), height: CVPixelBufferGetHeight(capturedImage))
                let qr_center = (code.topRight - code.bottomLeft) / 2 + code.bottomLeft
                let norm_point = CGPoint(x: qr_center.x / capturedCoordinateSys.width, y: qr_center.y / capturedCoordinateSys.height)
                let rayQuery = arFrame.raycastQuery(from: norm_point, allowing: .estimatedPlane, alignment: .any)
                if let result = vc.ar_session.raycast(rayQuery).first {
                    let newQRCode = QRCode(location: result.worldTransform.columns.3, message: code.messageString!)
                    if !codeWasDetected(newQRCode) {
                        detectedCodes.append(newQRCode) // TODO visualize detected QR Codes
                    }
                }
            }
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
        
        if !frameCollectionWriter.appendInfo(obj: frameInfo, metaInfo: jsonMeta) {
            print("ATTENTION: A full frame collection wasn't written to disk.")
        }
        
        // write to file if sequence finished
        
        frameCount += 1
        if frameCount >= EXPECTED_FPS * SEQUENCE_LENGTH_SEC {
            writeBuffersToFile()
        }
    }
    
    func stopRecording(notify tracker: ProgressTracker?) {
        progressTracker = tracker
        writeBuffersToFile()
    }
    
    private func writeBuffersToFile() {
        let dw = depthWriter!
        let vW = videoWriter!
        let cW = confidenceWriter!
        let fCW = frameCollectionWriter!
        
        writesQueued += [ScanConfig.saveRGBVideo, ScanConfig.saveDepthVideo, ScanConfig.saveConfidenceVideo,
                         ScanConfig.saveRGBVideo || ScanConfig.saveDepthVideo || ScanConfig.saveConfidenceVideo || ScanConfig.saveWorldMapInfo].filter{$0}.count

        if ScanConfig.saveWorldMapInfo {
            vc.ar_session.getCurrentWorldMap { worldMap, _ in
                if let map = worldMap {
                    fCW.setWorldMap(map: map)
                } else {
                    print("Couldn't save WorldMap!") // TODO warn user?
                }
                self.uploadQueue.async {[fCW] in
                    fCW.writeBufferToFile()
                }
            }
        }
        
        uploadQueue.async {[dw, vW, cW, fCW] in
            if ScanConfig.saveRGBVideo {
                vW.writeBufferToFile()
            }
            if ScanConfig.saveDepthVideo {
                dw.writeBufferToFile()
            }
            if ScanConfig.saveConfidenceVideo {
                cW.writeBufferToFile()
            }
            if (!ScanConfig.saveWorldMapInfo) && (ScanConfig.saveRGBVideo || ScanConfig.saveDepthVideo || ScanConfig.saveConfidenceVideo) {
                fCW.writeBufferToFile()
            }
        }
        
        if writesFinished >= writesQueued, // if nothing queued
           let pt = progressTracker{
            pt.notifyProgressRaw(value: 1)
        }
        
        frameCount = 0
        videoWriter = nil
        depthWriter = nil
        confidenceWriter = nil
        frameCollectionWriter = nil
    }
}
