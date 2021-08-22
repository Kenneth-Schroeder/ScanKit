//
//  FrameCollectionWriter.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 22.08.21.
//

import Foundation
import VideoToolbox
import ARKit

class FrameCollectionWriter: CollectionWriter {
    var meta: SequenceMetaInfo!
    var isWriting: Bool = false
    let jsonEncoder = JSONEncoder()
    var frameCollection: FrameCollection!
    weak var delegate: CollectionWriterDelegate?

    init(delegate: CollectionWriterDelegate, metaInfo: SequenceMetaInfo) {
        self.delegate = delegate
        self.meta = metaInfo
        meta.updateFilename()
        frameCollection = FrameCollection(/*numberOfFrames: meta.totalFrames*/)
    }

    func appendInfo(obj: FrameInfo, metaInfo: SequenceMetaInfo) -> Bool {
        guard isWriting == false else { return false }

        frameCollection.appendFrameInfo(obj)
        return true
    }

    func updateWorldMap(map: ARWorldMap, metaInfo: SequenceMetaInfo) {
        guard isWriting == false else { return }
        frameCollection.setWorldMap(map)
    }

    func updateQRCodes(_ codes: [QRCode]) {
        if frameCollection != nil { // might be nil, if frameCollectionWriter was just created and not yet lazy-initialized
            frameCollection.setQRCodes(codes)
        }
    }

    public func writeBufferToFile() {
        isWriting = true
        let queue = DispatchQueue(label: "frameCollectionWriterQueue", qos: .userInitiated)
        queue.async {
            if let data = try? self.jsonEncoder.encode(self.frameCollection) {
                do {
                    try data.write(to: self.meta.fullPath, options: .atomic)
                    print("finished writing JSON!")
                } catch {
                    print("Writing FrameCollection json file failed.")
                    print(error.localizedDescription)
                }
                // NOTE: this object is not reusable currently, assuming creation of new object after write
                self.delegate!.fileWritten()
            }
        }
    }

    public func getLastWrittenTitle() -> String {
        return meta.fileName
    }

    public func getCurrentOutputPath() -> URL {
        return self.meta.fullPath
    }

    public func getLastWrittenFrame() -> Int {
        return frameCollection.frames.count - 1
    }
}
