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

extension matrix_float3x3 {
    mutating func copy(from affine: CGAffineTransform) {
        columns.0 = Float3(Float(affine.a), Float(affine.c), Float(affine.tx))
        columns.1 = Float3(Float(affine.b), Float(affine.d), Float(affine.ty))
        columns.2 = Float3(0, 0, 1)
    }
}

extension MTKView : RenderDestinationProvider {
}

extension simd_float4x4 {
    func getPositionIfTransform() -> Float3 {
        return Float3(columns.3.x, columns.3.y, columns.3.z)
    }
}

extension ARCamera {
    func getPosition() -> Float3 {
        return transform.getPositionIfTransform()
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

protocol ProgressTracker: AnyObject {
    func notifyProgressRaw(value: Float)
    func notifyProgressPC(value: Float)
}

// https://stackoverflow.com/questions/28332946/how-do-i-get-the-current-date-in-short-format-in-swift
extension Date {
    func string(format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
}

extension CLLocationCoordinate2D: Identifiable {
    public var id: String {
        "\(latitude)-\(longitude)"
    }
}

// MARK: - Dir Size Calculation https://gist.github.com/NikolaiRuhe/408cefb953c4bea15506a3f80a3e5b96

public extension FileManager {

    /// Calculate the allocated size of a directory and all its contents on the volume.
    ///
    /// As there's no simple way to get this information from the file system the method
    /// has to crawl the entire hierarchy, accumulating the overall sum on the way.
    /// The resulting value is roughly equivalent with the amount of bytes
    /// that would become available on the volume if the directory would be deleted.
    ///
    /// - note: There are a couple of oddities that are not taken into account (like symbolic links, meta data of
    /// directories, hard links, ...).
    func allocatedSizeOfDirectory(at directoryURL: URL) throws -> UInt64 {

        // The error handler simply stores the error and stops traversal
        var enumeratorError: Error? = nil
        func errorHandler(_: URL, error: Error) -> Bool {
            enumeratorError = error
            return false
        }

        // We have to enumerate all directory contents, including subdirectories.
        let enumerator = self.enumerator(at: directoryURL,
                                         includingPropertiesForKeys: Array(allocatedSizeResourceKeys),
                                         options: [],
                                         errorHandler: errorHandler)!

        // We'll sum up content size here:
        var accumulatedSize: UInt64 = 0

        // Perform the traversal.
        for item in enumerator {

            // Bail out on errors from the errorHandler.
            if enumeratorError != nil { break }

            // Add up individual file sizes.
            let contentItemURL = item as! URL
            accumulatedSize += try contentItemURL.regularFileAllocatedSize()
        }

        // Rethrow errors from errorHandler.
        if let error = enumeratorError { throw error }

        return accumulatedSize
    }
}


fileprivate let allocatedSizeResourceKeys: Set<URLResourceKey> = [
    .isRegularFileKey,
    .fileAllocatedSizeKey,
    .totalFileAllocatedSizeKey,
]


fileprivate extension URL {

    func regularFileAllocatedSize() throws -> UInt64 {
        let resourceValues = try self.resourceValues(forKeys: allocatedSizeResourceKeys)

        // We only look at regular files.
        guard resourceValues.isRegularFile ?? false else {
            return 0
        }

        // To get the file's size we first try the most comprehensive value in terms of what
        // the file may use on disk. This includes metadata, compression (on file system
        // level) and block size.
        // In case totalFileAllocatedSize is unavailable we use the fallback value (excluding
        // meta data and compression) This value should always be available.
        return UInt64(resourceValues.totalFileAllocatedSize ?? resourceValues.fileAllocatedSize ?? 0)
    }
}
