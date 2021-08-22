//
//  ProgressorCollection.swift
//  Pods
//
//  Created by Chang, Hao on 24/05/2017.
//
//

import Foundation

struct ProgressorCollection {
    var progressors: [Progressor]
}

extension ProgressorCollection: Progressor {
    var progressViews: [ProgressorView] {
        return progressors.map { $0.progressViews }.flatMap { $0 }
    }
    
    init(parameter: Any?, parent: ProgressParent) {
        guard let progressorTypes = parameter as? [ProgressorType] else {
            fatalError(".async progressor parameter must be [Progressor].")
        }
        let progressors = progressorTypes.map {
            return Prog.shared.progressor(with: $0, parent: parent)
        }
        self.init(progressors: progressors)
    }
    
    /**
     The func will be executed before added to progress parent.
     
     - parameter parameter: The parameter passed in `ProgressorType.custom(identifier:parameter:)`
     */
    func prepareForProgress(parameter: Any? = nil) {
        guard let progressorTypes = parameter as? [ProgressorType] else {
            fatalError(".async progressor parameter must be [Progressor].")
        }
        progressors.enumerated().forEach {
            $0.element.prepareForProgress(parameter: progressorTypes[$0.offset].parameter)
        }
    }
    
    /**
     Progress starting animation.
     Always call completion at the end of starting animation
     
     - parameter parameter: The parameter passed in `ProgressorType.custom(identifier:parameter:)`
     - parameter completion: Callback function after starting animation
     */
    func startProgress(parameter: Any? = nil, completion: @escaping (() -> Void)) {
        guard let progressorTypes = parameter as? [ProgressorType] else {
            fatalError(".async progressor parameter must be [Progressor].")
        }
        var completionCount: Int = 0
        let done: () -> Void = {
            if completionCount == self.progressors.count {
                completion()
            }
        }
        progressors.enumerated().forEach {
            $0.element.startProgress(parameter: progressorTypes[$0.offset].parameter) {
                completionCount += 1
                done()
            }
        }
    }
    
    /**
     Update progress view for progress completion
     
     - parameter progress: completion percentage (suggested to be ranging from 0 to 1)
     */
    func update(progress: Float) {
        progressors.forEach {
            $0.update(progress: progress)
        }
    }
    
    /**
     Progress ending animation.
     Always call completion at the end of ending animation
     
     - parameter completion: Callback function after ending animation
     */
    func endProgress(completion: @escaping (() -> Void)) {
        var completionCount: Int = 0
        let done: () -> Void = {
            if completionCount == self.progressors.count {
                completion()
            }
        }
        progressors.forEach {
            $0.endProgress {
                completionCount += 1
                done()
            }
        }
    }
}
