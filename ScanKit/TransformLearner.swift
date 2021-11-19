//
//  TransformLearner.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 07.11.21.
//

import Foundation
// import _Differentiation // so sad it doesn't work

func constSIMDDouble4x4(_ val: Double) -> simd_double4x4 {
    return simd_double4x4(SIMD4(val,val,val,val), SIMD4(val,val,val,val), SIMD4(val,val,val,val), SIMD4(val,val,val,val) )
}

// https://www.ece.queensu.ca/people/S-D-Blostein/papers/PAMI-3DLS-1987.pdf
// https://en.wikipedia.org/wiki/Grid_reference_system
class TransformLearner {
    var originPoints: [simd_double4] = []
    var destinationPoints: [simd_double4] = []
    var currentX: simd_double4x4
    
    init(originPoints: [Float3], destinationPoints: [Float3]) {
        for oP in originPoints {
            self.originPoints.append(simd_double4(Double(oP[0]), Double(oP[1]), Double(oP[2]), 1))
        }
        for dP in destinationPoints {
            self.destinationPoints.append(simd_double4(Double(dP[0]), Double(dP[1]), Double(dP[2]), 1))
        }
        self.currentX = constSIMDDouble4x4(1)
    }
    
    func getTransform() -> simd_double4x4 {
        return currentX
    }
    
    func learn(iterations: Int = 1000) {
        _gradientDescent(iterations: iterations)
    }
    
    func _gradientDescent(iterations: Int) {
        let starting_lr: Double = 0.01
        let final_lr: Double = 0.00001
        for i in 1...iterations {
            let myGrads = matDerivativeOf(fn: loss, atX: currentX)
            let lr = starting_lr - Double(i)*(starting_lr-final_lr)/Double(iterations)
            print(lr)
            currentX = currentX - (myGrads * lr)
            print(loss(currentX))
        }
    }
    
    // https://stackoverflow.com/questions/31014918/derivative-function-in-swift
    func matDerivativeOf(fn: (simd_double4x4)->Double, atX x: simd_double4x4) -> simd_double4x4 {
        let h: Double = 0.00000001
        var result = constSIMDDouble4x4(0)
        for i in 0...3 {
            for j in 0...3 {
                var matH = constSIMDDouble4x4(0)
                matH[i][j] = h
                result[i][j] = (fn(x + matH) - fn(x))/h
            }
        }
        return result
    }
    
    func loss(_ x: simd_double4x4) -> Double{
        // X * pcC = grsC
        var l: Double = 0
        for (origP, destP) in zip(originPoints, destinationPoints) {
            // l += abs((x * origP - destP).sum())
            l += pow((abs(x * origP - destP)).sum(), 2) // pow instead of abs
        }

        return l
    }
}
