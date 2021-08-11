//
//  UIClasses.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 11.08.21.
//

import UIKit

class TileButton: UIButton {
    override func didMoveToWindow() {
        self.layer.cornerRadius = 10
        self.layer.shadowColor = UIColor.red.cgColor
        self.layer.shadowRadius = 5
        self.layer.shadowOpacity = 0.5
        self.layer.shadowOffset = CGSize(width: 5, height: 5)
    }
}
