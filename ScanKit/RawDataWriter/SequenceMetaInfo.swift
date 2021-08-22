//
//  SequenceMetaInfo.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 22.08.21.
//

import Foundation
import VideoToolbox

struct SequenceMetaInfo {
    var expectedFps: Int
    var resolution: CGSize!
    var path: URL!
    var filePrefix: String
    var fileExtension: String
    var fileName: String = ""

    var frameDuration: CMTime {
        return CMTimeMake(value: 1, timescale: Int32(expectedFps)) // frame duration = value/timescale
    }

    mutating func updateFilename() {
        fileName = filePrefix + "@" + String(NSDate().timeIntervalSince1970) + "." + fileExtension
    }

    var fullPath: URL {
        return path.appendingPathComponent(fileName)
    }

    init(filePrefix: String, fileExtension: String, expectedFps: Int) {
        self.filePrefix = filePrefix
        self.fileExtension = fileExtension
        self.expectedFps = 60
        updateFilename()
    }

    mutating func setResolutionAndPath(resolution: CGSize, path: URL) {
        self.resolution = resolution
        self.path = path
    }
    
    mutating func setPath(path: URL) {
        self.path = path
    }
}
