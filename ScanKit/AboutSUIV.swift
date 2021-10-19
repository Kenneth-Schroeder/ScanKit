//
//  AboutSUIV.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 07.10.21.
//

import SwiftUI

// https://stackoverflow.com/questions/58341820/isnt-there-an-easy-way-to-pinch-to-zoom-in-an-image-in-swiftui
import PDFKit

struct PhotoDetailView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = PDFDocument()
        guard let page = PDFPage(image: image) else { return view }
        view.document?.insert(page, at: 0)
        view.autoScales = true
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        // empty
    }
}

struct AboutSUIV: View { // Help, Details
    @Environment(\.horizontalSizeClass) var sizeClass
    private var main_menu_image = "main_menu"
    private var scan_view_image = "scan_view"
    private var projects_menu_image = "projects_menu"
    private var details_menu_image = "details_menu"
    
    private var main_menu_title = "Main Menu"
    private var scan_view_title = "Scanning Screen"
    private var projects_menu_title = "Projects Menu"
    private var details_menu_title = "Project Details Screen"
    
    private var main_menu_description = "The main menu is the app's startup screen. It allows the user to name the project and quickly select the data to be collected before beginning a scanning session. From here, the user can also reach the \"About\" and \"Projects\" pages. Details regarding the data format are available below."
    private var scan_view_description = "The scanning screen can be used to start and stop recordings using the green button. Additional controls are provided to change between different perspectives and underlay visualizations. The flashlight can be activated using the button on the right to light up dim environments."
    private var projects_menu_description = "The projects menu displays a list of all scanning projects, which are saved in the Documents folder of your device. The default project names contain data and the time of the recording. Clicking on an item reveals the project details."
    private var details_menu_description = "Project details contain the storage size, scan start and end time, location data (if enabled), and the settings that were selected for the scanning session. From here, you can also upload the entire project to a server via SFTP or open the projects folder in the Files app, which lets you share the data directly via AirDrop or external drives."
    private var format_text = "This zoomable diagram contains our format description. During the scanning procedure, huge amounts of data can accrue. Therefore, saving the data in chunks is necessary to not run out of main memory. We call these chunks FrameCollections. Each FrameCollection JSON file contains references to data frames of up to 10 seconds of a recording. 60 data frames are saved per second, each containing camera metadata, references to a video file with the RGB recording, and file names of the depth and confidence data. ARWorldMap data and QRCode data are not saved per frame but once per FrameCollection. Feel free to contact me for further information."
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    VStack {
                        HStack {
                            Text("Development").font(.title2).bold()
                            Spacer()
                        }
                        Spacer(minLength: 10)
                        Text("This App was developed by [Kenneth Schröder](https://www.linkedin.com/in/kenneth-schroeder-dev/) at the [Hasso Plattner Institute](https://hpi.de/en/index.html). The Code is Open Source and can be found on [GitHub](https://github.com/Kenneth-Schroeder/ScanKit).")
                        Spacer(minLength: 10)
                    }
                    VStack {
                        HStack {
                            Text("Usage").font(.title2).bold()
                            Spacer()
                        }
                        if sizeClass == .compact {
                            VStack {
                                HStack {
                                    Text(main_menu_title).font(.headline).foregroundColor(Color("Occa"))
                                    Spacer()
                                }
                                Image(main_menu_image).resizable().scaledToFit()
                                Text(main_menu_description)
                            }.padding()
                            VStack {
                                HStack {
                                    Text(scan_view_title).font(.headline).foregroundColor(Color("Occa"))
                                    Spacer()
                                }
                                Image(scan_view_image).resizable().scaledToFit()
                                Text(scan_view_description)
                            }.padding()
                            VStack {
                                HStack {
                                    Text(projects_menu_title).font(.headline).foregroundColor(Color("Occa"))
                                    Spacer()
                                }
                                Image(projects_menu_image).resizable().scaledToFit()
                                Text(projects_menu_description)
                            }.padding()
                            VStack {
                                HStack {
                                    Text(details_menu_title).font(.headline).foregroundColor(Color("Occa"))
                                    Spacer()
                                }
                                Image(details_menu_image).resizable().scaledToFit()
                                Text(details_menu_description)
                            }.padding()
                        } else {
                            HStack(alignment: .top) {
                                VStack {
                                    HStack {
                                        Text(main_menu_title).font(.headline).foregroundColor(Color("Occa"))
                                        Spacer()
                                    }
                                    Image(main_menu_image).resizable().scaledToFit()
                                    Text(main_menu_description)
                                }.padding()
                                VStack {
                                    HStack {
                                        Text(scan_view_title).font(.headline).foregroundColor(Color("Occa"))
                                        Spacer()
                                    }
                                    Image(scan_view_image).resizable().scaledToFit()
                                    Text(scan_view_description)
                                }.padding()
                            }
                            HStack(alignment: .top) {
                                VStack {
                                    HStack {
                                        Text(projects_menu_title).font(.headline).foregroundColor(Color("Occa"))
                                        Spacer()
                                    }
                                    Image(projects_menu_image).resizable().scaledToFit()
                                    Text(projects_menu_description)
                                }.padding()
                                VStack {
                                    HStack {
                                        Text(details_menu_title).font(.headline).foregroundColor(Color("Occa"))
                                        Spacer()
                                    }
                                    Image(details_menu_image).resizable().scaledToFit()
                                    Text(details_menu_description)
                                }.padding()
                            }
                        }
                        VStack {
                            HStack {
                                Text("Output Format").font(.headline).foregroundColor(Color("Occa"))
                                Spacer()
                            }
                            PhotoDetailView(image: UIImage(named: "format_description")!).frame(height: 400).border(Color("Occa"))
                            Text(format_text).lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                        }.padding()
                    }
                }
                Spacer()
            }
            .navigationTitle("About")
        }.navigationViewStyle(StackNavigationViewStyle()).accentColor(Color("Occa")) // https://stackoverflow.com/questions/65316497/swiftui-navigationview-navigationbartitle-layoutconstraints-issue/65316745
    }
}

struct AboutSUIV_Previews: PreviewProvider {
    static var previews: some View {
        AboutSUIV()
    }
}
