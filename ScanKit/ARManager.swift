//
//  ARManager.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 14.08.21.
//

import Foundation
import ARKit

class ARManager: NSObject, ARSessionDelegate {
    private var vc: ScanVC
    private var collector: RawDataCollector
    
    init(viewController: ScanVC) {
        self.vc = viewController
        collector = RawDataCollector(viewController: viewController)
        super.init()
    }
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        DispatchQueue.main.async {
            // Present an alert informing about the error that has occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.vc.resetTracking()
            }
            alertController.addAction(restartAction)
            self.vc.present(alertController, animated: true, completion: nil)
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // TODO Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // TODO Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        collector.collectDataOf(arFrame: frame)
    }
}
