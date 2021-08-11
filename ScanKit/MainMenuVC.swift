//
//  MainMenuVC.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 10.08.21.
//

import UIKit

class MainMenuVC: UIViewController {
    @IBOutlet var pointCloudButton: TileButton!
    @IBOutlet var rawDataButton: TileButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    // MARK: - point cloud button actions
    
    @IBAction func point_cloud_button_touched(_ sender: TileButton) {
        sender.alpha = 0.5
    }
    
    @IBAction func point_cloud_button_released_outside(_ sender: TileButton) {
        sender.alpha = 1.0
    }
    
    @IBAction func point_cloud_button_released_inside(_ sender: TileButton) {
        sender.alpha = 1.0
        guard let next_vc = storyboard?.instantiateViewController(withIdentifier: "point_cloud_recording_vc") as? PointCloudVC else {
            return
        }
        next_vc.modalPresentationStyle = .overFullScreen // formsheet, pageSheet, popover
        present(next_vc, animated: true)
    }
    
    // MARK: - raw data button actions
    
    @IBAction func raw_data_button_touched(_ sender: TileButton) {
        sender.alpha = 0.5
    }
    
    @IBAction func raw_data_button_released_outside(_ sender: TileButton) {
        sender.alpha = 1.0
    }
    
    @IBAction func raw_data_button_released_inside(_ sender: TileButton) {
        sender.alpha = 1.0
        guard let next_vc = storyboard?.instantiateViewController(withIdentifier: "raw_data_recording_vc") as? RawDataVC else {
            return
        }
        next_vc.modalPresentationStyle = .overFullScreen
        present(next_vc, animated: true)
    }
}
