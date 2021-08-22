//
//  UIClasses.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 11.08.21.
//

import UIKit

class RecordButton: UIButton {
    override func didMoveToWindow() {
        self.layer.borderWidth = 5
        self.layer.borderColor = UIColor.white.cgColor
        self.layer.backgroundColor = UIColor.green.cgColor
        self.layer.cornerRadius = 30
    }
}

class TileButton: UIButton {
    override func didMoveToWindow() {
        self.layer.cornerRadius = 10
        self.layer.shadowColor = UIColor.red.cgColor
        self.layer.shadowRadius = 5
        self.layer.shadowOpacity = 0.5
        self.layer.shadowOffset = CGSize(width: 5, height: 5)
    }
}

class RoundedButton: UIButton {
    override func didMoveToWindow() {
        self.layer.cornerRadius = 8
    }
}
