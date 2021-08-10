//
//  MainMenuVC.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 10.08.21.
//

import UIKit

class MainMenuVC: UIViewController {
    @IBOutlet var pointCloudButton: TileButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func point_cloud_recording_touched(_ sender: TileButton) {
        sender.alpha = 0.5
    }
    
    @IBAction func point_cloud_recording_released_outside(_ sender: TileButton) {
        sender.alpha = 1.0
    }
    
    @IBAction func point_cloud_recording_released_inside(_ sender: TileButton) {
        sender.alpha = 1.0
        guard let next_vc = storyboard?.instantiateViewController(withIdentifier: "point_cloud_recording_vc") as? PointCloudVC else {
            return
        }
        next_vc.modalPresentationStyle = .overFullScreen // formsheet, pageSheet, popover
        present(next_vc, animated: true)
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
