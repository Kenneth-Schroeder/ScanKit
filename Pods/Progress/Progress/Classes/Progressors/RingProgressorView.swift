 //
//  RingProgressorView.swift
//  Pods
//
//  Created by Chang, Hao on 21/05/2017.
//
//

import UIKit

public typealias RingProgressorParameter = (type: RingProgressType, color: UIColor, radius: CGFloat,  lineWidth: CGFloat)

public let DefaultRingProgressorParameter: RingProgressorParameter = (.proportional, UIColor.black.withAlphaComponent(0.5), 12, 4)

public enum RingProgressType {
    case
    proportional,
    endless
}

class RingProgressorView: ProgressorView {
    var type: RingProgressType = .proportional
    var progress: CGFloat = 0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var ringColor: UIColor = UIColor.black.withAlphaComponent(0.5)
    var radius: CGFloat = 12
    var lineWidth: CGFloat = 4
    
    private weak var shapeLayer: CAShapeLayer?
    private var isAnimating: Bool = false { didSet { setNeedsDisplay() } }
    
    
    func startAnimation() {
        if isAnimating { return }
        // remove old shape layer if any
        self.shapeLayer?.removeFromSuperlayer()
        let shapeLayer = CAShapeLayer()
        
        let circleCenter: CGPoint = CGPoint(x: frame.width/2, y: frame.height/2)
        var path: UIBezierPath {
            let path = UIBezierPath()
            path.addArc(withCenter: CGPoint.zero, radius: radius, startAngle: -CGFloat(Double.pi/2), endAngle: CGFloat(Double.pi) * 2 - CGFloat(Double.pi/2), clockwise: true)
            return path
        }
        
        // primary path
        let path_2 = path
        let layer_2 = CAShapeLayer()
        layer_2.strokeColor = ringColor.cgColor
        layer_2.lineWidth = lineWidth
        layer_2.fillColor = UIColor.clear.cgColor
        layer_2.backgroundColor = UIColor.clear.cgColor
        layer_2.path = path_2.cgPath
        
        let animation_2 = CABasicAnimation(keyPath: "strokeEnd")
        animation_2.fromValue = 0
        animation_2.toValue = 0.4
        animation_2.duration = 0.6
        animation_2.repeatCount = Float.infinity
        animation_2.isRemovedOnCompletion = false
        animation_2.autoreverses = true
        animation_2.timingFunction = CAMediaTimingFunction.init(name: CAMediaTimingFunctionName.easeOut)
        layer_2.add(animation_2, forKey: "strokeEndAnimation")
        
        shapeLayer.addSublayer(layer_2)
        
        let animation_rotate = CABasicAnimation(keyPath: "transform.rotation.z")
        animation_rotate.fromValue = 0
        animation_rotate.toValue = Double.pi * 2
        animation_rotate.duration = 0.8
        animation_rotate.repeatCount = Float.infinity
        shapeLayer.add(animation_rotate, forKey: "rotation")
        
        shapeLayer.transform = CATransform3DTranslate(shapeLayer.transform, circleCenter.x, circleCenter.y, 0)
        
        // save shape layer
        
        layer.addSublayer(shapeLayer)
        self.shapeLayer = shapeLayer
        isAnimating = true
    }
    
    private func animate(from: CGFloat, to: CGFloat, completion: @escaping ()->Void) {
        // remove old shape layer if any
        self.shapeLayer?.removeFromSuperlayer()
        let shapeLayer = CAShapeLayer()
        
        let circleCenter: CGPoint = CGPoint(x: frame.width/2, y: frame.height/2)
        var path: UIBezierPath {
            let path = UIBezierPath()
            path.addArc(withCenter: CGPoint.zero, radius: radius, startAngle: -CGFloat(Double.pi/2) + CGFloat(Double.pi*2)*from, endAngle: -CGFloat(Double.pi/2) + CGFloat(Double.pi*2)*to, clockwise: true)
            return path
        }
        
        
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            completion()
        }
        // primary path
        let path_2 = path
        let layer_2 = CAShapeLayer()
        layer_2.strokeColor = ringColor.cgColor
        layer_2.lineWidth = lineWidth
        layer_2.fillColor = UIColor.clear.cgColor
        layer_2.backgroundColor = UIColor.clear.cgColor
        layer_2.path = path_2.cgPath
        
        let animation_2 = CABasicAnimation(keyPath: "strokeEnd")
        animation_2.fromValue = 0
        animation_2.toValue = 1
        animation_2.duration = Prog.maxEndingAnimationDuration * Double(to-from)
        animation_2.repeatCount = 1
        animation_2.isRemovedOnCompletion = false
        animation_2.timingFunction = CAMediaTimingFunction.init(name: CAMediaTimingFunctionName.easeOut)
        layer_2.add(animation_2, forKey: "strokeEndAnimation")
        
        shapeLayer.addSublayer(layer_2)
        shapeLayer.transform = CATransform3DTranslate(shapeLayer.transform, circleCenter.x, circleCenter.y, 0)
        
        // save shape layer
        layer.addSublayer(shapeLayer)
        self.shapeLayer = shapeLayer
        CATransaction.commit()
    }
    
    func stopAnimation() {
        if !isAnimating { return }
        isAnimating = false
        self.shapeLayer?.removeFromSuperlayer()
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        if !isAnimating {
            let path = UIBezierPath()
            path.addArc(withCenter: CGPoint(x: frame.width/2, y: frame.height/2), radius: radius, startAngle: -CGFloat(Double.pi/2), endAngle: CGFloat(Double.pi) * 2 * progress - CGFloat(Double.pi/2), clockwise: true)
            ringColor.setStroke()
            path.lineWidth = lineWidth
            path.stroke()
        }
    }
    
    
    override func prepareForProgress(parameter: Any? = nil) {
        
        var param : RingProgressorParameter = DefaultRingProgressorParameter
        if let p = parameter as? RingProgressorParameter {
            param = p
        } else {
            print("invalid ring progressor type. \(String(describing: parameter))")
            print("using default parameter instead. \(DefaultRingProgressorParameter)")
        }
        self.type = param.type
        self.ringColor = param.color
        self.lineWidth = param.lineWidth
        self.radius = param.radius
        
        backgroundColor = .clear
    }
    override func startProgress(parameter: Any? = nil, completion: @escaping (() -> Void)) {
        switch type {
        case .proportional: progress = 0
        case .endless: startAnimation()
        }
        completion()
    }
    override func update(progress: Float) {
        switch type {
        case .proportional: self.progress = CGFloat(progress)
        case .endless: break
        }
    }
    override func endProgress(completion: @escaping (() -> Void)) {
        switch type {
        case .proportional: animate(from: progress, to: 1, completion: completion)
        case .endless: completion()
        }
        
    }
}
