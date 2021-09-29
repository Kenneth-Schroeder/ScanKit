//
//  ProjectDetailsSUIV.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 29.09.21.
//

import SwiftUI

struct ProjectDetailsSUIV: View {
    var text: String
    
    var body: some View {
        NavigationView {
            Text("Scan Details")
            .navigationTitle(text)
        }.navigationViewStyle(StackNavigationViewStyle())
    }
}

struct ProjectDetailsSUIV_Previews: PreviewProvider {
    static var previews: some View {
        ProjectDetailsSUIV(text: "PreviewTestTest")
    }
}
