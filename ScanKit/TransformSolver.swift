//
//  TransformLearner.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 19.11.21.
//

import Foundation
import Accelerate.vecLib.LinearAlgebra

// credit to Tobias Pietz for optimal idea
class TransformSolver {
    var originPoints: [[Double]] = []
    var destinationColumns: [[Double]] = []
    var currentX: simd_double4x4? = nil
    
    init(originPoints: [Float3], destinationPoints: [Float3]) {
        for oP in originPoints {
            self.originPoints.append([Double(oP[0]), Double(oP[1]), Double(oP[2]), 1])
        }
        for coord in 0...2 {
            var coord_vec: [Double] = []
            for i in 0..<destinationPoints.count {
                coord_vec.append(Double(destinationPoints[i][coord]))
            }
            self.destinationColumns.append(coord_vec)
        }
        self.destinationColumns.append(Array(repeating: 1, count: destinationPoints.count))
    }
    
    func getTransform() -> simd_double4x4 {
        if currentX != nil {
            return currentX!
        }
        
        currentX = constSIMDDouble4x4(0)
        
        guard var x = currentX else {
            return constSIMDDouble4x4(0)
        }
        
        for (idx, column) in destinationColumns.enumerated() {
            let result_column = _solveLeastSquare(A: originPoints, B: column)
            
            guard let rs = result_column else {
                return constSIMDDouble4x4(0)
            }
            
            for (cIdx, num) in rs.enumerated() {
                x[cIdx][idx] = num
            }
        }
        
        return x
    }
    
    // https://stackoverflow.com/questions/37836311/function-which-returns-the-least-squares-solution-to-a-linear-matrix-equation
    func _solveLeastSquare(A: [[Double]], B: [Double]) -> [Double]? {
        precondition(A.count == B.count, "Non-matching dimensions")

        var mode = Int8(bitPattern: UInt8(ascii: "N")) // "Normal" mode
        var nrows = CInt(A.count)
        var ncols = CInt(A[0].count)
        var nrhs = CInt(1)
        var ldb = max(nrows, ncols)

        // Flattened columns of matrix A
        var localA = (0 ..< nrows * ncols).map { (i) -> Double in
            A[Int(i % nrows)][Int(i / nrows)]
        }

        // Vector B, expanded by zeros if ncols > nrows
        var localB = B
        if ldb > nrows {
            localB.append(contentsOf: [Double](repeating: 0.0, count: Int(ldb - nrows)))
        }

        var wkopt = 0.0
        var lwork: CInt = -1
        var info: CInt = 0

        // First call to determine optimal workspace size
        var nrows_copy = nrows // Workaround for SE-0176
        dgels_(&mode, &nrows, &ncols, &nrhs, &localA, &nrows_copy, &localB, &ldb, &wkopt, &lwork, &info)
        lwork = Int32(wkopt)

        // Allocate workspace and do actual calculation
        var work = [Double](repeating: 0.0, count: Int(lwork))
        dgels_(&mode, &nrows, &ncols, &nrhs, &localA, &nrows_copy, &localB, &ldb, &work, &lwork, &info)

        if info != 0 {
            print("A does not have full rank; the least squares solution could not be computed.")
            return nil
        }
        return Array(localB.prefix(Int(ncols)))
    }
}
