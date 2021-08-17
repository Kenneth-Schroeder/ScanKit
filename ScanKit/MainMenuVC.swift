//
//  MainMenuVC.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 10.08.21.
//

import UIKit
import UniformTypeIdentifiers

class MainMenuVC: UIViewController, UIDocumentPickerDelegate {
    @IBOutlet var pointCloudButton: TileButton!
    @IBOutlet var rawDataButton: TileButton!
    var folderSelectionTouched: Bool = false
    var rawDataTouched: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func displayFolderSelection() {
        // lots of deprecated documentation, look under "Initializers" section https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller
        let dp = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder])
        dp.delegate = self
        dp.allowsMultipleSelection = false
        present(dp, animated: true, completion: nil)
    }
    
    // MARK: - folder selection button actions
    
    @IBAction func folder_selection_button_touched(_ sender: TileButton) {
        sender.alpha = 0.5
        folderSelectionTouched = true
    }
    
    @IBAction func folder_selection_button_released_outside(_ sender: TileButton) {
        sender.alpha = 1.0
        folderSelectionTouched = false
    }
    
    @IBAction func folder_selection_button_released_inside(_ sender: TileButton) {
        if !folderSelectionTouched {
            return
        }
        sender.alpha = 1.0
        folderSelectionTouched = false
        displayFolderSelection()
    }
    
    // MARK: - raw data button actions
    
    @IBAction func raw_data_button_touched(_ sender: TileButton) {
        sender.alpha = 0.5
        rawDataTouched = true
    }
    
    @IBAction func raw_data_button_released_outside(_ sender: TileButton) {
        sender.alpha = 1.0
        rawDataTouched = false
    }
    
    @IBAction func raw_data_button_released_inside(_ sender: TileButton) {
        if !rawDataTouched {
            return
        }
        sender.alpha = 1.0
        rawDataTouched = false
        guard let next_vc = storyboard?.instantiateViewController(withIdentifier: "recording_vc") as? ScanVC else {
            return
        }
        next_vc.modalPresentationStyle = .overFullScreen
        present(next_vc, animated: true)
    }
    
    // MARK: - UIDocumentPickerDelegate

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if !urls[0].startAccessingSecurityScopedResource() {
            fatalError("App was not granted access to the selected folder.")
        } // https://stackoverflow.com/questions/34636150/no-permission-to-view-document-passed-back-from-ios-document-provider-on-open-op/34658428
        ScanConfig.url = urls[0]
    }
}
