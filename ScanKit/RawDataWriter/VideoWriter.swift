//
//  VideoWriter.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 22.08.21.
//

import Foundation

import AVFoundation
import UIKit
import Photos
import ARKit
import VideoToolbox

struct VideoSettings {
    private var avCodecKey: AVVideoCodecType = .jpeg // .proRes4444 // .h264 // .jpeg // .hevcWithAlpha

    func getOutputSettings(size: CGSize) -> [String: Any] {
        let videoCompressionProps: [String: Any] = [
            AVVideoQualityKey: NSNumber(value: ScanConfig.rgbQuality) // seems to not only work with AVVideoCodecKey set to AVVideoCodecType.jpeg
        ]

        return [
            AVVideoCompressionPropertiesKey: videoCompressionProps,
            AVVideoCodecKey: avCodecKey,
            AVVideoWidthKey: NSNumber(value: Float(size.width)),
            AVVideoHeightKey: NSNumber(value: Float(size.height))
        ]
    }
}

class VideoWriter: CollectionWriter {
    private var meta: SequenceMetaInfo!
    private var videoSettings: VideoSettings = VideoSettings()
    private var videoWriter: AVAssetWriter! // writes audio or video file to specified location on device filesystem
    private var videoWriterInput: AVAssetWriterInput! //
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor!
    private var frameCounter = 0
    private var pixelFormatType: OSType!
    weak var delegate: CollectionWriterDelegate?

    private var isReadyForData: Bool { videoWriterInput?.isReadyForMoreMediaData ?? false }

    // - MARK: INIT

    init(delegate: CollectionWriterDelegate, sampleBuffer: CVPixelBuffer, metaInfo: SequenceMetaInfo) {
        self.delegate = delegate
        self.meta = metaInfo
        self.meta.updateFilename()
        updateWriter()
    }

    private func updateWriter() {
        videoWriter = createVideoWriter(outputURL: meta.fullPath)
        videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings.getOutputSettings(size: meta.resolution))

        if !ScanConfig.saveRGBVideo {
            return
        }
        
        if videoWriter.canAdd(videoWriterInput) {
            videoWriter.add(videoWriterInput)
        } else {
            fatalError("canAddInput() returned false")
        }

        // The pixel buffer adaptor must be created before we start writing.
        createPixelBufferAdaptor()

        if videoWriter.startWriting() == false {
            print(videoWriter.error?.localizedDescription ?? "videoWriter.startWriting was not successful")
            fatalError("startWriting() failed")
        }

        videoWriter.startSession(atSourceTime: CMTime.zero)
        precondition(pixelBufferAdaptor.pixelBufferPool != nil, "nil pixelBufferPool")
    }

    private func createVideoWriter(outputURL: URL) -> AVAssetWriter {
        guard let assetWriter = try? AVAssetWriter(outputURL: outputURL, fileType: AVFileType.mov) else {
            fatalError("AVAssetWriter() failed")
        }

        guard assetWriter.canApply(outputSettings: videoSettings.getOutputSettings(size: meta.resolution), forMediaType: .video) else {
            fatalError("canApplyOutputSettings() failed, either settings have wrong format or are incompatible with MediaType")
            // no useful error messages provided by Apple, just comment out this guard and check exceptions
        }

        return assetWriter
    }

    // AVAssetExportPresetHEVCHighestQualityWithAlpha
    private func createPixelBufferAdaptor() {
        let sourcePixelBufferAttributesDictionary = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: NSNumber(value: Float(meta.resolution.width)),
            kCVPixelBufferHeightKey as String: NSNumber(value: Float(meta.resolution.height))
        ]
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput,
                                                                  sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary)
    }

    // - MARK: Append PixelBuffer

    func appendPixelBuffer(_ pixelBufferIn: CVPixelBuffer) -> Bool {
        if !isReadyForData {
            return false
        }

        let presentationTime = CMTimeMultiply(meta.frameDuration, multiplier: Int32(frameCounter))
        if !pixelBufferAdaptor.append(pixelBufferIn, withPresentationTime: presentationTime) {
            print("appending to pixelBufferAdaptor failed this time")
            // print(videoWriter.error.debugDescription)
        }

        frameCounter += 1

        return true
    }
    
    // - MARK: Saving Video

    public func writeBufferToFile() {
        precondition(videoWriter != nil, "Call start() to initialize the writer")
        
        if frameCounter == 0 {
            self.delegate!.fileWritten() // tell delegate that we are done here
            return
        }
        
        let queue = DispatchQueue(label: "rgbWriterQueue", qos: .userInitiated, attributes: .concurrent)
        videoWriterInput.requestMediaDataWhenReady(on: queue) {
            self.videoWriterInput.markAsFinished()
            self.videoWriter.finishWriting {
                print("finished writing RGB-Video")
            }
            self.delegate!.fileWritten()
        }
        frameCounter = 0
    }

    public func getLastWrittenTitle() -> String {
        return meta.fileName
    }

    public func getCurrentOutputPath() -> URL {
        return self.meta.fullPath
    }

    public func getLastWrittenFrame() -> Int {
        return frameCounter - 1
    }

    public func getResolution() -> CGSize {
        return meta.resolution
    }
}
