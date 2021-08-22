//
//  ScanConfig.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 14.08.21.
//

import Foundation

class ScanConfig {
    static var url: URL?
    static var underlayIndex: Int = 0
    static var viewshedActive: Bool = false
    static var numGridPoints: Int = 49_152
    static let viewshedMaxCount: Int = 49_152 // TODO might need adjustment with better lidar data from apple
    
    static let sobelDepthThreshold:Float = 0.05 /// if the corresponding value of a particle on the depth sobel texture is above this value, it will be marked as unselected and later deleted (because it lies on an edge on the depth image)
    static let sobelYThreshold:Float = 0.5 /// if the corresponding value of a particle on the Y sobel texture is above this value, it will be kept (because it lies on an edge on the Y image and is likely important for details)
    static let sobelYEdgeSamplingRate:Float = 0.5
    static let sobelSurfaceSamplingRate:Float = 0.01 /// if a particle doesn't lie on an edge in both sobel textures, it most likely lies on a flat surface, thus it is randomly marked as unselected (and later on deleted) with a probability of this value
    static let maxPointDepth:Float = 1.2 /// particles more than this far away from the camera at the time of recording will be deleted
    static let minPointDepth:Float = 0.6 /// particles less than this far away from the camera at the time of recording will be deleted
    
    static let rgbQuality: Float = 0.5
    
    static var saveRGBVideo: Bool = true
    static var saveDepthVideo: Bool = true
    static var saveConfidenceVideo: Bool = true
    static var saveWorldMapInfo: Bool = false
    
    static var isRecording: Bool = false
}
