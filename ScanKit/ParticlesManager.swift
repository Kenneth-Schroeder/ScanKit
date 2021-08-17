//
//  ParticlesManager.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 17.08.21.
//

import Foundation
import Metal

class ParticlesManager {
    private let device: MTLDevice
    private var cameraResolution: Float2
    
    lazy var gridPointsBuffer = MetalBuffer<Float2>(device: device, array: updateGridPoints(), index: kGridPoints.rawValue) // MetalBuffer containing the 'numGridPoints'-many point coordinates selected by CPU for GPU
    var gridSize: Int { return gridPointsBuffer.count }
    
    init(metalDevice device: MTLDevice, cameraResolution: Float2) {
        self.device = device
        self.cameraResolution = cameraResolution
    }
    
    // Makes sample points on camera image, also precompute the anchor point for animation
    private func updateGridPoints() -> [Float2] {
        let gridArea = cameraResolution.x * cameraResolution.y
        let spacing = sqrt(gridArea / Float(ScanConfig.numGridPoints))
        let deltaX = Int(round(cameraResolution.x / spacing))
        let deltaY = Int(round(cameraResolution.y / spacing))
        
        var points = [Float2]()
        for gridY in 0 ..< deltaY {
            let alternatingOffsetX = Float(gridY % 2) * spacing / 2
            for gridX in 0 ..< deltaX {
                let cameraPoint = Float2(alternatingOffsetX + (Float(gridX) + 0.5) * spacing, (Float(gridY) + 0.5) * spacing)
                
                points.append(cameraPoint)
            }
        }
        
        return points
    }
    
    func updateSampleGrid() {
        gridPointsBuffer = MetalBuffer<Float2>(device: device,
                                               array: updateGridPoints(),
                                               index: kGridPoints.rawValue,
                                               options: [])
    }
}
