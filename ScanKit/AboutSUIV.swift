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
    
    private var main_menu_description = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
    private var scan_view_description = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
    private var projects_menu_description = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
    private var details_menu_description = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
    
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
                            HStack {
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
                            HStack {
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
                            Text("(zoomable) Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
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
