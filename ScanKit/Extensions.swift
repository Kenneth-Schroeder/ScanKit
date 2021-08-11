//
//  Extensions.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 11.08.21.
//

import Foundation
import MetalKit

extension MTKView : RenderDestinationProvider {
}

protocol RenderDestinationProvider {
    var currentRenderPassDescriptor: MTLRenderPassDescriptor? { get }
    var currentDrawable: CAMetalDrawable? { get }
    var colorPixelFormat: MTLPixelFormat { get set }
    var depthStencilPixelFormat: MTLPixelFormat { get set }
    var sampleCount: Int { get set }
}
