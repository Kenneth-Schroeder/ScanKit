//
//  ProjectsVC.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 23.09.21.
//

import UIKit
import UniformTypeIdentifiers

class ProjectsVC: UIViewController {
    
    @IBOutlet var projectsLabel: UILabel!
    var projectNames: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Projects"
        
        getProjectNames()
        var displayString = ""
        for name in projectNames {
            displayString += "\n" + name
        }
        projectsLabel.text = displayString
    }
    
    func getProjectNames() { // https://stackoverflow.com/questions/42894421/listing-only-the-subfolders-within-a-folder-swift-3-0-ios-10
        let filemgr = FileManager.default
        let dirPaths = filemgr.urls(for: .documentDirectory, in: .userDomainMask)
        let myDocumentsDirectory = dirPaths[0]
        
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(at: myDocumentsDirectory, includingPropertiesForKeys: nil, options: [])
            let subdirPaths = directoryContents.filter{ $0.hasDirectoryPath }
            let subdirNamesStr = subdirPaths.map{ $0.lastPathComponent }
            projectNames = subdirNamesStr.filter { $0 != ".Trash" }

            // now do whatever with the onlyFileNamesStr & subdirNamesStr
        } catch let error as NSError {
            print(error.localizedDescription)
        }
    }
}
