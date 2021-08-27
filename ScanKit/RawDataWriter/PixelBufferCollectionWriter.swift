//
//  PixelBufferCollectionWriter.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 22.08.21.
//

import Foundation
import VideoToolbox

class PixelBufferCollectionWriter: CollectionWriter {
    var meta: SequenceMetaInfo!
    var frameSizeBytes: Int!
    var content: [[UInt8]]!
    var isWriting: Bool = false
    weak var delegate: CollectionWriterDelegate?
    private var frameCounter: Int = 0

    init(delegate: CollectionWriterDelegate, sampleBuffer: CVPixelBuffer, metaInfo: SequenceMetaInfo) {
        self.delegate = delegate
        self.meta = metaInfo
        self.frameSizeBytes = CVPixelBufferGetBytesPerRow(sampleBuffer) * Int(meta.resolution.height)
        meta.updateFilename()
        content = []
    }

    func appendBuffer(_ buffer: CVPixelBuffer) -> Bool {
        guard isWriting == false else { return false }

        precondition(CVPixelBufferGetWidth(buffer) == Int(meta.resolution.width))
        precondition(CVPixelBufferGetHeight(buffer) == Int(meta.resolution.height))
        precondition(CVPixelBufferGetBytesPerRow(buffer) == frameSizeBytes/Int(meta.resolution.height))

        var arr = Array(repeating: UInt8(), count: frameSizeBytes)
        pixelBufferToArray(pixelBuffer: buffer, arr: &arr, byteCount: frameSizeBytes)

        content.append(arr)
        frameCounter += 1
        return true
    }

    func writeBufferToFile() {
        isWriting = true
        let queue = DispatchQueue(label: "pixelBufferWriterQueue", qos: .userInitiated)
        queue.async {
            do {
                // self.isInitialized = false
                let data = Data(self.content.reduce([], +)) as NSData
                try data.write(to: self.meta.fullPath, options: .atomic)
                // try data.compressed(using: .zlib).write(to: self.meta.fullPath, options: .atomic)
                print("finished writing pixelbuffer collection")
            } catch {
                print("Writing PixelBuffer collection to file failed.")
                print(error.localizedDescription)
            }
            // NOTE: this object is not reusable currently, assuming creation of new object after write
            self.delegate!.fileWritten()
        }
    }

    private func pixelBufferToArray(pixelBuffer: CVPixelBuffer, arr: inout [UInt8], byteCount: Int) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .init(rawValue: 0))
        guard let originBaseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
        memcpy(&arr, originBaseAddress, byteCount)
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .init(rawValue: 0))
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
