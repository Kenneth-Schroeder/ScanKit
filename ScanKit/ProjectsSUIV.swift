//
//  ProjectsSUIV.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 29.09.21.
//

import SwiftUI

func getProjectNames() -> [String] { // https://stackoverflow.com/questions/42894421/listing-only-the-subfolders-within-a-folder-swift-3-0-ios-10
    let filemgr = FileManager.default
    let dirPaths = filemgr.urls(for: .documentDirectory, in: .userDomainMask)
    let myDocumentsDirectory = dirPaths[0]
    var projectNames:[String] = []
    
    do {
        let directoryContents = try FileManager.default.contentsOfDirectory(at: myDocumentsDirectory, includingPropertiesForKeys: nil, options: [])
        let subdirPaths = directoryContents.filter{ $0.hasDirectoryPath }
        let subdirNamesStr = subdirPaths.map{ $0.lastPathComponent }
        projectNames = subdirNamesStr.filter { $0 != ".Trash" }
    } catch let error as NSError {
        print(error.localizedDescription)
    }
    return projectNames.sorted()
}

// https://youtu.be/diK5WkGpCUE https://developer.apple.com/videos/play/wwdc2019/231/ https://medium.com/flawless-app-stories/swiftui-dynamic-list-identifiable-73c56215f9ff https://youtu.be/k5rupivxnMA
struct ProjectsSUIV: View { // SUIV = SwiftUI View
    var projectNames = getProjectNames()
    
    var body: some View {
        NavigationView {
            VStack {
                List(projectNames, id: \.hash) { project in
                    NavigationLink(destination: ProjectDetailsSUIV(projectName: project), label: {
                        Text(project)
                    })
                }
                Spacer()
            }
            .navigationTitle("Projects")
        }.navigationViewStyle(StackNavigationViewStyle()).accentColor(Color("Occa")) // https://stackoverflow.com/questions/65316497/swiftui-navigationview-navigationbartitle-layoutconstraints-issue/65316745
    }
}

struct ProjectsSUIV_Previews: PreviewProvider {
    static var previews: some View {
        ProjectsSUIV()
    }
}
