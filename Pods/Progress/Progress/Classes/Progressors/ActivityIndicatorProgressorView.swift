//
//  ActivityIndicatorProgressorView.swift
//  Pods
//
//  Created by Chang, Hao on 21/05/2017.
//
//

import UIKit

class ActivityIndicatorProgressorView: ProgressorView {
    var indicatorView: UIActivityIndicatorView = UIActivityIndicatorView()
    override func layoutSubviews() {
        super.layoutSubviews()
        indicatorView.center = center
    }
    
    override func prepareForProgress(parameter: Any? = nil) {
        addSubview(indicatorView)
        indicatorView.startAnimating()
    }
    override func endProgress(completion: @escaping (() -> Void)) {
        completion()
    }
}
