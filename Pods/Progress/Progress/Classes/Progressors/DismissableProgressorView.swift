//
//  DismissableProgressorView.swift
//  Pods
//
//  Created by Chang, Hao on 25/05/2017.
//
//

import UIKit

class DismissableProgressorView: ProgressorView {
    var parentUserInteractionEnabled: Bool?
    var dismissGestureRecognizer: UIGestureRecognizer?
    
    required init(parameter parameters: Any?, parent: ProgressParent) {
        super.init(parameter: parameters, parent: parent)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func prepareForProgress(parameter: Any?) {
        guard let parent = progressParent else { return }
        parentUserInteractionEnabled = parent.progressParentUserInteractionEnabled
        
        parent.progressParentUserInteractionEnabled = true
        dismissGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissProgress))
        parent.add(progressGestureRecognizer: dismissGestureRecognizer!)
        
    }
    
    @objc func dismissProgress() {
        guard let parent = progressParent,
            let parentUserInteractionEnabled = parentUserInteractionEnabled,
            let dismissGestureRecognizer = dismissGestureRecognizer else { return }
        Prog.dismiss(in: parent) {
            parent.remove(progressGestureRecognizer: dismissGestureRecognizer)
            parent.progressParentUserInteractionEnabled = parentUserInteractionEnabled
        }
    }
}
