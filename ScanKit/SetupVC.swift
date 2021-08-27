//
//  MainMenuVC.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 10.08.21.
//

import UIKit
import UniformTypeIdentifiers

class SetupVC: UIViewController, UIDocumentPickerDelegate {
    @IBOutlet var projectNameField: UITextField!
    @IBOutlet var scanButton: TileButton!
    @IBOutlet var rgbQualitySlider: UISlider!
    @IBOutlet var rgbSwitch: UISwitch!
    @IBOutlet var depthSwitch: UISwitch!
    @IBOutlet var confidenceSwitch: UISwitch!
    @IBOutlet var worldmapSwitch: UISwitch!
    @IBOutlet var qrCodeSwitch: UISwitch!
    
    var scanButtonTouched: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ScanConfig.url = getDocumentsDirectory().appendingPathComponent(getDefaultProjectName(), isDirectory: true)
        
        // update UI according to ScanConfig
        rgbQualitySlider.setValue(ScanConfig.rgbQuality, animated: false)
        rgbSwitch.setOn(ScanConfig.saveRGBVideo, animated: false)
        depthSwitch.setOn(ScanConfig.saveDepthVideo, animated: false)
        confidenceSwitch.setOn(ScanConfig.saveConfidenceVideo, animated: false)
        worldmapSwitch.setOn(ScanConfig.saveWorldMapInfo, animated: false)
        qrCodeSwitch.setOn(ScanConfig.detectQRCodes, animated: false)
    }
    
    func displayFolderSelection() {
        // lots of deprecated documentation, look under "Initializers" section https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller
        let dp = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder])
        dp.delegate = self
        dp.allowsMultipleSelection = false
        present(dp, animated: true, completion: nil)
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
    
    // MARK: - scan button actions
    
    @IBAction func scan_button_touched(_ sender: TileButton) {
        sender.alpha = 0.5
        scanButtonTouched = true
    }
    
    @IBAction func scan_button_released_outside(_ sender: TileButton) {
        sender.alpha = 1.0
        scanButtonTouched = false
    }
    
    @IBAction func scan_button_released_inside(_ sender: TileButton) {
        sender.alpha = 1.0
        if !scanButtonTouched || ScanConfig.url == nil {
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
        
        scanButtonTouched = false
        guard let next_vc = storyboard?.instantiateViewController(withIdentifier: "recording_vc") as? ScanVC else {
            return
        }
        next_vc.modalPresentationStyle = .overFullScreen
        present(next_vc, animated: true)
    }
    
    // MARK: - setup UI functions
    
    @IBAction func rgbQualitySlider_changed(_ sender: UISlider) {
        ScanConfig.rgbQuality = sender.value
    }
    
    @IBAction func rgbSwitch_toggled(_ sender: UISwitch) {
        ScanConfig.saveRGBVideo = sender.isOn
    }
    
    @IBAction func depthSwitch_toggled(_ sender: UISwitch) {
        ScanConfig.saveDepthVideo = sender.isOn
    }
    
    @IBAction func confidenceSwitch_toggled(_ sender: UISwitch) {
        ScanConfig.saveConfidenceVideo = sender.isOn
    }
    
    @IBAction func worldmapSwitch_toggled(_ sender: UISwitch) {
        ScanConfig.saveWorldMapInfo = sender.isOn
    }
    
    @IBAction func qrCodeSwitch_toggled(_ sender: UISwitch) {
        ScanConfig.detectQRCodes = sender.isOn
    }
    
    // MARK: - UIDocumentPickerDelegate

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if !urls[0].startAccessingSecurityScopedResource() {
            fatalError("App was not granted access to the selected folder.")
        } // https://stackoverflow.com/questions/34636150/no-permission-to-view-document-passed-back-from-ios-document-provider-on-open-op/34658428
        ScanConfig.url = urls[0]
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
        df.dateFormat = "yyyy-MM-dd_hh:mm:ss"
        let now: String = df.string(from: Date())
        return now
    }
}
