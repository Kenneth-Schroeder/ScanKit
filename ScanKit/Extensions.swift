//
//  Extensions.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 11.08.21.
//

import Foundation
import MetalKit
import ARKit

typealias Float2 = SIMD2<Float>
typealias Float3 = SIMD3<Float>

func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
}

func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
}

func / (lhs: CGPoint, rhs: Float) -> CGPoint {
    return CGPoint(x: lhs.x / CGFloat(rhs), y: lhs.y / CGFloat(rhs))
}

extension CGPoint {
    func convertCoordinateSystemReverseXY(from: CGSize, to: CGSize) -> CGPoint {
        let widthFactor = to.width / from.height
        let heightFactor = to.height / from.width
        return CGPoint(x: y * heightFactor, y: x * widthFactor )
    }
}

extension Float {
    static let degreesToRadian = Float.pi / 180
}

extension MTKView : RenderDestinationProvider {
}

extension ARCamera {
    func getPosition() -> Float3 {
        return Float3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }
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
