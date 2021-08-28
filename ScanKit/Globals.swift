//
//  Globals.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 11.08.21.
//

import Foundation
import MetalKit

// The max number of command buffers in flight
let kMaxBuffersInFlight: Int = 3

// Vertex data for an image plane
let kImagePlaneVertexData: [Float] = [
    -1.0, -1.0,  0.0, 1.0,
    1.0, -1.0,  1.0, 1.0,
    -1.0,  1.0,  0.0, 0.0,
    1.0,  1.0,  1.0, 0.0,
]

let deviceOrientation = UIInterfaceOrientation.portrait
