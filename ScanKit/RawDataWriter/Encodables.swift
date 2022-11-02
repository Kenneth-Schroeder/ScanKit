//
//  Encodables.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 22.08.21.
//

import Foundation
import ARKit

// MARK: - SIMD Matrix Extensions

// https://stackoverflow.com/questions/63661474/how-can-i-encode-an-array-of-simd-float4x4-elements-in-swift-convert-simd-float
extension simd_float3x3: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        try self.init(container.decode([SIMD3<Float>].self))
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode([columns.0, columns.1, columns.2])
    }
}

extension simd_float4x4: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        try self.init(container.decode([SIMD4<Float>].self))
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode([columns.0, columns.1, columns.2, columns.3])
    }
}

// MARK: - Frame Codables

struct FrameLocation: Codable {
    var fileName: String
    var frame: Int
    var resolution: CGSize

    init(fileName: String, frameNumber: Int, resolution: CGSize) {
        self.fileName = fileName
        self.frame = frameNumber
        self.resolution = resolution
    }
}

class FrameCollection: Encodable {
    var frames = [FrameInfo]()
    var worldMap: ARWorldMap?
    var qrCodes: [QRCode]?

    func appendFrameInfo(_ frameInfo: FrameInfo) {
        frames.append(frameInfo)
    }

    func setWorldMap(_ map: ARWorldMap) {
        worldMap = map
    }

    func setQRCodes(_ codes: [QRCode]) {
        qrCodes = codes
    }

    func reset() {
        frames = []
    }
}

class FrameInfo: Encodable { // Codable for JSON, class instead of struct for less copying
    var rgbVideoFrame: FrameLocation?
    var depthVideoFrame: FrameLocation?
    var confidenceVideoFrame: FrameLocation?
    var timestamp: Int
    var cameraEulerAngle: simd_float3
    var cameraIntrinsics: simd_float3x3
    var cameraTransform: simd_float4x4
    var cameraViewMatrix: simd_float4x4
    var cameraProjectionMatrix: simd_float4x4
    var worldMappingStatus: Int
    var anyFrameSet: Bool = false
    
    private enum CodingKeys: String, CodingKey { // which variables should be encoded
        case rgbVideoFrame, depthVideoFrame, confidenceVideoFrame, timestamp, cameraEulerAngle, cameraIntrinsics, cameraTransform, cameraViewMatrix, cameraProjectionMatrix, worldMappingStatus
    }

    init(ofFrame frame: ARFrame) {
        timestamp = Int(NSDate().timeIntervalSince1970)
        cameraEulerAngle = frame.camera.eulerAngles
        cameraIntrinsics = frame.camera.intrinsics
        cameraTransform = frame.camera.transform
        cameraViewMatrix = frame.camera.viewMatrix(for: UIInterfaceOrientation.landscapeRight) // keep landscapeRight even with portrait orientation, since ARKit provides data in landscape format
        cameraProjectionMatrix = frame.camera.projectionMatrix
        worldMappingStatus = frame.worldMappingStatus.rawValue // TODO: check why .description doesn't work
    }

    func setRGBFrame(_ location: FrameLocation) {
        if location.frame > 0 {
            rgbVideoFrame = location
            anyFrameSet = true
        }
    }

    func setDepthFrame(_ location: FrameLocation) {
        if location.frame > 0 {
            depthVideoFrame = location
            anyFrameSet = true
        }
    }

    func setConfidenceFrame(_ location: FrameLocation) {
        if location.frame > 0 {
            confidenceVideoFrame = location
            anyFrameSet = true
        }
    }
}

// MARK: - ARWorldMap Extensions

extension MTLBuffer {
    /// copies the content of the buffer to a swift array
    func copyTo<Element>(_ array: inout [Element]) { // inout important for actual by reference modification
        let byteCount = array.count * MemoryLayout<Element>.stride // * 3
        precondition(byteCount == length, "Mismatch between the byte count of the array's contents and the MTLBuffer length.")
        memcpy( &array, contents(), byteCount)
    }
}

struct Point: Codable {
    // swiftlint:disable identifier_name
    var x: Float = 0
    var y: Float = 0
    var z: Float = 0
    // swiftlint:enable identifier_name
}

struct Face: Codable {
    // swiftlint:disable identifier_name
    var p1: UInt32 = 0
    var p2: UInt32 = 0
    var p3: UInt32 = 0
    // swiftlint:enable identifier_name
}

extension ARMeshAnchor: Encodable {

    enum CodingKeys: String, CodingKey {
        case points
        case faces
        case classifications
        case normals
        case transform
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        var points = Array(repeating: Point(), count: geometry.vertices.count) // custom type for correct slide size
        geometry.vertices.buffer.copyTo(&points)

        try container.encode(points, forKey: CodingKeys.points)

        var faces = Array(repeating: Face(), count: geometry.faces.count) // custom type for correct slide size
        geometry.faces.buffer.copyTo(&faces)

        try container.encode(faces, forKey: CodingKeys.faces)

        var normals = Array(repeating: Point(), count: geometry.normals.count) // custom type for correct slide size
        geometry.normals.buffer.copyTo(&normals)

        try container.encode(normals, forKey: CodingKeys.normals)

        try container.encode(transform, forKey: CodingKeys.transform)

        guard let classifs = geometry.classification else {
            return
        }

        var classifications = Array(repeating: UInt8(), count: classifs.count)
        classifs.buffer.copyTo(&classifications)

        try container.encode(classifications, forKey: CodingKeys.classifications)
    }
}

func valueOf(planeClassification: ARPlaneAnchor.Classification) -> String {
    switch planeClassification {
    case .wall:
        return "wall"
    case .floor:
        return "floor"
    case .ceiling:
        return "ceiling"
    case .table:
        return "table"
    case .seat:
        return "seat"
    case .door:
        return "door"
    case .window:
        return "window"
    default:
        return "none"
    }
}

extension ARPlaneGeometry: Encodable {

    enum CodingKeys: String, CodingKey {
        case vertices
        case textureCoordinates
        case triangleCount
        case triangleIndices
        case boundaryVertices
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(vertices, forKey: CodingKeys.vertices)
        try container.encode(textureCoordinates, forKey: CodingKeys.textureCoordinates)
        try container.encode(triangleCount, forKey: CodingKeys.triangleCount)
        try container.encode(triangleIndices, forKey: CodingKeys.triangleIndices)
        try container.encode(boundaryVertices, forKey: CodingKeys.boundaryVertices)
    }

}

extension ARPlaneAnchor: Encodable {

    enum CodingKeys: String, CodingKey {
        case alignment
        case geometry
        case center
        case classification
        case transform
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.center, forKey: CodingKeys.center)
        try container.encode(self.alignment.rawValue, forKey: CodingKeys.alignment)
        try container.encode(valueOf(planeClassification: classification), forKey: CodingKeys.classification)
        try container.encode(self.geometry, forKey: CodingKeys.geometry)
        try container.encode(self.transform, forKey: CodingKeys.transform)
    }

}

extension ARPointCloud: Encodable {

    enum CodingKeys: String, CodingKey {
        case points
        case identifiers
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(points, forKey: CodingKeys.points)
        try container.encode(identifiers, forKey: CodingKeys.identifiers)
    }
}

extension ARWorldMap: Encodable {

    enum CodingKeys: String, CodingKey {
        case meshAnchors
        case planeAnchors
        case center
        case extent
        case featurePoints
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(center, forKey: CodingKeys.center)
        try container.encode(extent, forKey: CodingKeys.extent)
        try container.encode(rawFeaturePoints, forKey: CodingKeys.featurePoints)

        let mAnchors = anchors.filter { anchor in
            return anchor.isKind(of: ARMeshAnchor.self)
        } as! [ARMeshAnchor]

        try container.encode(mAnchors, forKey: CodingKeys.meshAnchors)

        let pAnchors = anchors.filter { anchor in
            return anchor.isKind(of: ARPlaneAnchor.self)
        } as! [ARPlaneAnchor]

        try container.encode(pAnchors, forKey: CodingKeys.planeAnchors)
    }
}

// MARK: - QR Codes

struct QRCode: Encodable {
    var location: simd_float3
    var message: String

    init(location: simd_float4, message: String) {
        self.location = simd_float3(location.x, location.y, location.z)
        self.message = message
    }

    func squaredDistanceTo(code: QRCode) -> Float {
        return simd_distance_squared(location, code.location)
    }
}

// MARK: - MetaData

struct ScanMetaData: Codable {
    var latitude: CLLocationDegrees?
    var longitude: CLLocationDegrees?
    var scanStart: TimeInterval
    var scanEnd: TimeInterval
    
    var savePointCloud: Bool = ScanConfig.savePointCloud
    var saveRGBVideo: Bool = ScanConfig.saveRGBVideo
    var rgbQuality: Float = ScanConfig.rgbQuality
    var saveDepthVideo: Bool = ScanConfig.saveDepthVideo
    var saveConfidenceVideo: Bool = ScanConfig.saveConfidenceVideo
    var saveWorldMapInfo: Bool = ScanConfig.saveWorldMapInfo
    var detectQRCodes: Bool = ScanConfig.detectQRCodes
    
    init(location: CLLocation?, startTime: TimeInterval, endTime: TimeInterval) {
        self.latitude = location?.coordinate.latitude
        self.longitude = location?.coordinate.longitude
        self.scanStart = startTime
        self.scanEnd = endTime
    }
}

struct ScanMetaDataPrintable {
    var latitude: String = "-"
    var longitude: String = "-"
    var latitudePrecise: CLLocationDegrees?
    var longitudePrecise: CLLocationDegrees?
    var scanStart: String = "-"
    var scanEnd: String = "-"
    
    var savePointCloud: String = "-"
    var saveRGBVideo: String = "-"
    var rgbQuality: String = "-"
    var saveDepthVideo: String = "-"
    var saveConfidenceVideo: String = "-"
    var saveWorldMapInfo: String = "-"
    var detectQRCodes: String = "-"
    
    init(fromScanMetaData meta: ScanMetaData?) {
        if let m = meta {
            longitudePrecise = m.longitude
            latitudePrecise = m.latitude
            
            if let long = m.longitude {
                longitude = String(format: "%.5f", long)
            }
            if let lat = m.latitude {
                latitude = String(format: "%.5f", lat)
            }
            
            let startDate = Date(timeIntervalSince1970: m.scanStart)
            let endDate = Date(timeIntervalSince1970: m.scanEnd)
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            //dateFormatter.dateFormat = "YY/MM/dd at hh:mm"
            
            scanStart = dateFormatter.string(from: startDate)
            scanEnd = dateFormatter.string(from: endDate)
            
            savePointCloud = m.savePointCloud ? "Yes" : "No"
            saveRGBVideo = m.saveRGBVideo ? "Yes" : "No"
            rgbQuality = String(format: "%.3f", m.rgbQuality)
            saveDepthVideo = m.saveDepthVideo ? "Yes" : "No"
            saveConfidenceVideo = m.saveConfidenceVideo ? "Yes" : "No"
            saveWorldMapInfo = m.saveWorldMapInfo ? "Yes" : "No"
            detectQRCodes = m.detectQRCodes ? "Yes" : "No"
        }
    }
}
