//
//  AboutSUIV.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 07.10.21.
//

import SwiftUI

struct AboutSUIV: View {
    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section(header: Text("Usage")) {
                        Text("...")
                        //Image("fall-leaves").resizable()
                        //                    .scaledToFit()
                    }
                    Section(header: Text("Development")) {
                        Text("...")
                        Link("GitHub Repository", destination: URL(string: "https://github.com/Kenneth-Schroeder/ScanKit")!)
                        Link("Hasso Plattner Institute", destination: URL(string: "https://hpi.de/en/index.html")!)
                        Link("Kenneth Schröder", destination: URL(string: "https://www.linkedin.com/in/kenneth-schroeder-dev/")!)
                    }
                }
                Spacer()
            }
            .navigationTitle("About")
        }.navigationViewStyle(StackNavigationViewStyle()) // https://stackoverflow.com/questions/65316497/swiftui-navigationview-navigationbartitle-layoutconstraints-issue/65316745
    }
}

struct AboutSUIV_Previews: PreviewProvider {
    static var previews: some View {
        AboutSUIV()
    }
}
