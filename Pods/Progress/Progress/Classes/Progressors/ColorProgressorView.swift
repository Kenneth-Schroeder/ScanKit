//
//  ColorProgressorView.swift
//  Pods
//
//  Created by Chang, Hao on 21/05/2017.
//
//

import UIKit

public typealias ColorProgressorParameter = UIColor

public let DefaultColorProgressorParameter: ColorProgressorParameter = UIColor.white.withAlphaComponent(0.5)

class ColorProgressorView: ProgressorView {
    override func prepareForProgress(parameter: Any? = nil) {
        
        var param: ColorProgressorParameter = DefaultColorProgressorParameter
        if let p = parameter as? ColorProgressorParameter {
            param = p
        } else {
            print("invalid color progressor parameter. \(String(describing: parameter))")
            print("using default parameter instead. \(param)")
        }
        backgroundColor = param
    }
    
    /*
     override func startProgress(parameter: Any? = nil, completion: @escaping (() -> Void)) {
     completion()
     }
     override func update(progress: Float) {
     }
     override func endProgress(completion: @escaping (() -> Void)) {
     completion()
     }
     */
}
