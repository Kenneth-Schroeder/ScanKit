//
//  Progressor.swift
//  Pods
//
//  Created by Chang, Hao on 24/05/2017.
//
//

import Foundation

public protocol Progressor {
    var progressViews: [ProgressorView] { get }
    init(parameter: Any?, parent: ProgressParent)
    /**
     The func will be executed before added to progress parent.
     
     - parameter parameter: The parameter passed in `ProgressorType.custom(identifier:parameter:)`
     */
    func prepareForProgress(parameter: Any?)
    
    /**
     Progress starting animation.
     Always call completion at the end of starting animation
     
     - parameter parameter: The parameter passed in `ProgressorType.custom(identifier:parameter:)`
     - parameter completion: Callback function after starting animation
     */
    func startProgress(parameter: Any?, completion: @escaping (() -> Void))
    
    /**
     Update progress view for progress completion
     
     - parameter progress: completion percentage (suggested to be ranging from 0 to 1)
     */
    func update(progress: Float)
    
    /**
     Progress ending animation.
     Always call completion at the end of ending animation
     
     - parameter completion: Callback function after ending animation
     */
    func endProgress(completion: @escaping (() -> Void))
}
