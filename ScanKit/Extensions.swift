//
//  Extensions.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 11.08.21.
//

import Foundation
import MetalKit

typealias Float2 = SIMD2<Float>
typealias Float3 = SIMD3<Float>

extension Float {
    static let degreesToRadian = Float.pi / 180
}

extension MTKView : RenderDestinationProvider {
}

protocol RenderDestinationProvider {
    var currentRenderPassDescriptor: MTLRenderPassDescriptor? { get }
    var currentDrawable: CAMetalDrawable? { get }
    var colorPixelFormat: MTLPixelFormat { get set }
    var depthStencilPixelFormat: MTLPixelFormat { get set }
    var sampleCount: Int { get set }
}

protocol CollectionWriter: AnyObject {
    var delegate: CollectionWriterDelegate? { get set }
    func getCurrentOutputPath() -> URL
    func getLastWrittenFrame() -> Int
    func getLastWrittenTitle() -> String
}

protocol CollectionWriterDelegate: AnyObject {
    func fileWritten()
}
