//
//  MainMenuVC.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 10.08.21.
//

import UIKit
import UniformTypeIdentifiers
import SwiftUI

class SetupVC: UIViewController {
    @IBOutlet var dataRateLabel: UILabel!
    @IBOutlet var projectNameField: UITextField!
    @IBOutlet var scanButton: TileButton!
    @IBOutlet var projecstButton: TileButton!
    @IBOutlet var pointCloudSwitch: UISwitch!
    @IBOutlet var rgbQualitySlider: UISlider!
    @IBOutlet var rgbSwitch: UISwitch!
    @IBOutlet var depthSwitch: UISwitch!
    @IBOutlet var confidenceSwitch: UISwitch!
    @IBOutlet var worldmapSwitch: UISwitch!
    @IBOutlet var qrCodeSwitch: UISwitch!
    @IBOutlet var titleLabels: [UILabel]!
    @IBOutlet var descriptionLabels: [UILabel]!
    @IBOutlet var mainTitleLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ScanConfig.url = getDocumentsDirectory().appendingPathComponent(getDefaultProjectName(), isDirectory: true)
        
        // update UI according to ScanConfig
        pointCloudSwitch.setOn(ScanConfig.savePointCloud, animated: false)
        rgbQualitySlider.setValue(ScanConfig.rgbQuality, animated: false)
        rgbSwitch.setOn(ScanConfig.saveRGBVideo, animated: false)
        depthSwitch.setOn(ScanConfig.saveDepthVideo, animated: false)
        confidenceSwitch.setOn(ScanConfig.saveConfidenceVideo, animated: false)
        worldmapSwitch.setOn(ScanConfig.saveWorldMapInfo, animated: false)
        qrCodeSwitch.setOn(ScanConfig.detectQRCodes, animated: false)
        updateDataEstimate()
        
        projectNameField.attributedPlaceholder = NSAttributedString(string: "<default project name>",
                                                                    attributes: [NSAttributedString.Key.foregroundColor: UIColor.gray])
        
        // Adjust label text size according to device size
        let screenWidth = view.frame.width
        //for labl in titleLabels {
        //    labl.font = UIFont(name: "Geeza Pro Bold", size: screenWidth / 40.0)
        //}
        //for labl in descriptionLabels {
        //    labl.font = UIFont(name: "Geeza Pro", size: screenWidth / 50.0)
        //}
        mainTitleLabel.font = UIFont(name: "Apple SD Gothic Neo Bold", size: screenWidth / 5.0)
    }
    
    func updateDataEstimate() {
        var estimate: Float = 0
        
        if ScanConfig.savePointCloud {
            estimate += 1
        }
        if ScanConfig.saveRGBVideo {
            estimate += (30 + 577 * pow(ScanConfig.rgbQuality, 4))/10
        }
        if ScanConfig.saveDepthVideo {
            estimate += 118.0/10
        }
        if ScanConfig.saveConfidenceVideo {
            estimate += 30.0/10
        }
        if ScanConfig.saveWorldMapInfo {
            estimate += 15 // note: increasing over time
        }
        dataRateLabel.text = String(format: "Estimated Data Rate: %.2f MB/s", estimate)
    }
    
    // MARK: - project name field actions
    
    @IBAction func project_name_value_changed(_ sender: UITextField) {
        sender.resignFirstResponder()
        var text = sender.text
        if text == "" {
            text = nil
        }
        ScanConfig.url = getDocumentsDirectory().appendingPathComponent(sender.text ?? getDefaultProjectName(), isDirectory: true)
    }
    
    // MARK: - scan button
    
    @IBAction func scan_button_pressed(_ sender: TileButton) {
        if ScanConfig.url == nil {
            return
        }
        
        if !FileManager.default.fileExists(atPath: ScanConfig.url!.path) {
            do {
                try FileManager.default.createDirectory(atPath: ScanConfig.url!.path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print(error.localizedDescription)
                return
            }
        }
        
        guard let next_vc = storyboard?.instantiateViewController(withIdentifier: "recording_vc") as? ScanVC else {
            return
        }
        next_vc.modalPresentationStyle = .overFullScreen
        //present(next_vc, animated: true)
        navigationController?.pushViewController(next_vc, animated: true)
    }
    
    // MARK: - setup UI functions
    
    @IBAction func rgbQualitySlider_changed(_ sender: UISlider) {
        ScanConfig.rgbQuality = sender.value
        updateDataEstimate()
    }
    
    @IBAction func pointCloudSwitch_toggled(_ sender: UISwitch) {
        ScanConfig.savePointCloud = sender.isOn
        updateDataEstimate()
    }
    
    @IBAction func rgbSwitch_toggled(_ sender: UISwitch) {
        ScanConfig.saveRGBVideo = sender.isOn
        updateDataEstimate()
    }
    
    @IBAction func depthSwitch_toggled(_ sender: UISwitch) {
        ScanConfig.saveDepthVideo = sender.isOn
        updateDataEstimate()
    }
    
    @IBAction func confidenceSwitch_toggled(_ sender: UISwitch) {
        ScanConfig.saveConfidenceVideo = sender.isOn
        updateDataEstimate()
    }
    
    @IBAction func worldmapSwitch_toggled(_ sender: UISwitch) {
        ScanConfig.saveWorldMapInfo = sender.isOn
        updateDataEstimate()
    }
    
    @IBAction func qrCodeSwitch_toggled(_ sender: UISwitch) {
        ScanConfig.detectQRCodes = sender.isOn
        updateDataEstimate()
    }
    
    @IBAction func projectsButton_pressed(_ sender: TileButton) {
        let next_vc = UIHostingController(rootView: ProjectsSUIV())
        present(next_vc, animated: true)
    }
    
    // https://www.hackingwithswift.com/example-code/system/how-to-find-the-users-documents-directory
    // default hidden in Files App, but can be made visible in Info.plist
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
    
    // https://cocoacasts.com/swift-fundamentals-how-to-convert-a-date-to-a-string-in-swift
    func getDefaultProjectName() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HH:mm:ss"
        let now: String = df.string(from: Date())
        return now
    }
}
