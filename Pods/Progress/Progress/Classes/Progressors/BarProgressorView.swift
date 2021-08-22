//
//  BarProgressorView.swift
//  Pods
//
//  Created by Chang, Hao on 23/05/2017.
//
//

import UIKit

public typealias BarProgressorParameter = (type: BarProgressorType, side: BarProgressorSide, barColor: UIColor, barHeight: CGFloat)

public let DefaultBarProgressorParameter: BarProgressorParameter = (.proportional, .top, UIColor.black.withAlphaComponent(0.5), 2)

public enum BarProgressorType {
    case proportional, endless
}

public enum BarProgressorSide {
    case top, bottom
}

class BarProgressorView: ProgressorView {
    
    var type: BarProgressorType = .proportional
    var side: BarProgressorSide = .top
    var progress: CGFloat = 0 { didSet { setNeedsDisplay() } }
    
    var barHeight: CGFloat = 2
    var barColor: UIColor = UIColor.black.withAlphaComponent(0.5)
    
    var barY: CGFloat {
        var y: CGFloat = 0 + barHeight/2
        if side == .bottom { y = bounds.maxY - barHeight/2 }
        return y
    }
    
    private weak var shapeLayer: CAShapeLayer?
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        if type == .proportional {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: barY))
            path.addLine(to: CGPoint(x: rect.maxX * progress, y: barY))
            path.close()
            path.lineWidth = barHeight
            barColor.setStroke()
            path.stroke()
        }
    }
    
    override func prepareForProgress(parameter: Any? = nil) {
        backgroundColor = .clear
        var param: BarProgressorParameter = DefaultBarProgressorParameter
        if let p = parameter as? BarProgressorParameter {
            param = p
        } else {
            print("invalid bar progressor parameter. \(String(describing: parameter))")
            print("using default parameter instead. \(param)")
        }
        type = param.type
        side = param.side
        barColor = param.barColor
        barHeight = param.barHeight
    }
    
    
    
    
    override func startProgress(parameter: Any? = nil, completion: @escaping (() -> Void)) {
        if type == .endless {
            startAnimation()
        }
        completion()
    }
    
    override func update(progress: Float) {
        self.progress = CGFloat(progress)
    }
    
    override func endProgress(completion: @escaping (() -> Void)) {
        if type == .proportional {
            animate(from: progress, to: 1, completion: completion)
        } else {
            completion()
        }
    }
    
    
    private func animate(from: CGFloat, to: CGFloat, completion: @escaping ()->Void) {
        // remove old shape layer if any
        self.shapeLayer?.removeFromSuperlayer()
        let shapeLayer = CAShapeLayer()
        
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            completion()
        }
        // primary path
        let path = UIBezierPath()
        path.move(to: CGPoint(x: bounds.maxX * progress, y: barY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: barY))
        path.close()
        
        let layer_2 = CAShapeLayer()
        layer_2.strokeColor = barColor.cgColor
        layer_2.lineWidth = barHeight
        layer_2.fillColor = UIColor.clear.cgColor
        layer_2.backgroundColor = UIColor.clear.cgColor
        layer_2.path = path.cgPath
        
        let animation_2 = CABasicAnimation(keyPath: "strokeEnd")
        animation_2.fromValue = from
        animation_2.toValue = to
        animation_2.duration = Double(to - from) * Prog.maxEndingAnimationDuration
        animation_2.repeatCount = 1
        animation_2.isRemovedOnCompletion = false
        animation_2.timingFunction = CAMediaTimingFunction.init(name: CAMediaTimingFunctionName.easeOut)
        layer_2.add(animation_2, forKey: "strokeEndAnimation")
        
        shapeLayer.addSublayer(layer_2)
        
        // save shape layer
        layer.addSublayer(shapeLayer)
        self.shapeLayer = shapeLayer
        CATransaction.commit()
    }
    
    func startAnimation() {
        // remove old shape layer if any
        self.shapeLayer?.removeFromSuperlayer()
        let shapeLayer = CAShapeLayer()
        
        // primary path
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: barY))
        path.addLine(to: CGPoint(x: bounds.width / 2, y: barY))
        path.close()
        
        let layer_2 = CAShapeLayer()
        layer_2.strokeColor = barColor.cgColor
        layer_2.lineWidth = barHeight
        layer_2.fillColor = UIColor.clear.cgColor
        layer_2.backgroundColor = UIColor.clear.cgColor
        layer_2.path = path.cgPath
        
        let animation_1 = CABasicAnimation(keyPath: "transform.translation.x")
        animation_1.fromValue = -bounds.width / 2
        animation_1.toValue = bounds.maxX
        animation_1.duration = 0.8
        animation_1.repeatCount = Float.infinity
        layer_2.add(animation_1, forKey: "translationAnimation")
        
        shapeLayer.addSublayer(layer_2)
        
        // save shape layer
        layer.addSublayer(shapeLayer)
        self.shapeLayer = shapeLayer
    }
}
