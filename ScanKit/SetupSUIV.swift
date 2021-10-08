//
//  SetupSUIV.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 08.10.21.
//

import SwiftUI

struct ThickDivider: View {
    let color: Color = Color("Occa")
    let height: CGFloat = 3
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: height)
    }
}

// https://www.hackingwithswift.com/quick-start/swiftui/customizing-button-with-buttonstyle
struct GrowingButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color("Occa"))
            .foregroundColor(.white)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 1.2 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

// https://stackoverflow.com/questions/63651077/how-to-center-crop-an-image-in-swiftui
extension Image {
    func centerCropped() -> some View {
        GeometryReader { geo in
            self
            .resizable()
            .scaledToFill()
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }
}

struct ScanVC_representable: UIViewControllerRepresentable {
    func makeUIViewController(context: UIViewControllerRepresentableContext<ScanVC_representable>) -> ScanVC {
        let storyboard = UIStoryboard(name: "Main", bundle: nil) // storyboard file name
        let next_vc = storyboard.instantiateViewController(withIdentifier: "recording_vc") as! ScanVC
        return next_vc
    }

    func updateUIViewController(_ uiViewController: ScanVC, context: UIViewControllerRepresentableContext<ScanVC_representable>) { }
}

class SetupHostingController: UIHostingController<SetupSUIV> {
    required init?(coder: NSCoder) {
        super.init(coder: coder, rootView: SetupSUIV());
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
}

struct SetupSUIV: View {
    @State private var savePointCloud = ScanConfig.savePointCloud
    @State private var saveRGBVideo = ScanConfig.saveRGBVideo
    @State private var saveDepthVideo = ScanConfig.saveDepthVideo
    @State private var saveConfidenceVideo = ScanConfig.saveConfidenceVideo
    @State private var saveWorldMapInfo = ScanConfig.saveWorldMapInfo
    @State private var detectQRCodes = ScanConfig.detectQRCodes
    @State private var rgbQuality = ScanConfig.rgbQuality
    @State private var title: String = ""
    @State private var isPresentingProjects: Bool = false
    @State private var isPresentingAbout: Bool = false
    @State private var isPresentingScan: Bool = false
    @State private var dataRateText = "Estimated Data Rate: "
    
    private var mainColor = Color("Occa")
    
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
        dataRateText = String(format: "Estimated Data Rate: %.2f MB/s", estimate)
    }
    
    init() {
        UITableView.appearance().separatorStyle = .none
        UITableViewCell.appearance().backgroundColor = .clear
        UITableView.appearance().backgroundColor = .clear
        ScanConfig.url = getDocumentsDirectory().appendingPathComponent(getDefaultProjectName(), isDirectory: true)
    }
    
    var body: some View {
        ZStack {
            Image("background").centerCropped().ignoresSafeArea(.all)
            VStack {
                Text("ScanKit").font(Font.custom("Apple SD Gothic Neo Bold", size: 60)).padding(.top, 30)
                //ThickDivider()
                List {
                    Section(header: Text("Scan Settings")) {
                        TextField("Project Title", text: $title, onEditingChanged: { edit in
                            var project_title: String? = title
                            if title == "" { project_title = nil }
                            ScanConfig.url = getDocumentsDirectory().appendingPathComponent(project_title ?? getDefaultProjectName(), isDirectory: true)
                        }).font(.title3).listRowBackground(Color.clear)
                        HStack {
                            VStack {
                                HStack {
                                    Text("Point Cloud").font(.title3)
                                    Spacer()
                                }
                                HStack {
                                    Text("On-the-fly generation of a colored point cloud, saved to documents folder in the .las file format.").font(.caption2)
                                    Spacer()
                                }
                            }.layoutPriority(1.0)
                            Toggle("", isOn: $savePointCloud).onChange(of: savePointCloud) { value in
                                ScanConfig.savePointCloud = value
                                updateDataEstimate()
                            }.toggleStyle(SwitchToggleStyle(tint: mainColor))
                        }.listRowBackground(Color.clear)
                        HStack {
                            VStack {
                                HStack {
                                    Text("RGB Video").font(.title3)
                                    Spacer()
                                }
                                HStack {
                                    Text("Record all images captured during the ARSession as video and save it to the specified location.").font(.caption2)
                                    Spacer()
                                }
                            }.layoutPriority(1.0)
                            Toggle("", isOn: $saveRGBVideo).onChange(of: saveRGBVideo) { value in
                                ScanConfig.saveRGBVideo = value
                                updateDataEstimate()
                            }.toggleStyle(SwitchToggleStyle(tint: mainColor))
                        }.listRowBackground(Color.clear)
                        HStack {
                            VStack {
                                HStack {
                                    Text("RGB Quality").font(.title3)
                                    Spacer()
                                }
                                HStack {
                                    Text("Adjust the JPEG compression quality of the saved RGB video.").font(.caption2)
                                    Spacer()
                                }
                            }.layoutPriority(1.0)
                            Slider(
                                value: $rgbQuality,
                                in: 0...1,
                                onEditingChanged: { editing in
                                    ScanConfig.rgbQuality = rgbQuality
                                    updateDataEstimate()
                                }
                            ).frame(width: 100).accentColor(mainColor)
                        }.listRowBackground(Color.clear)
                        HStack {
                            VStack {
                                HStack {
                                    Text("Depth Data").font(.title3)
                                    Spacer()
                                }
                                HStack {
                                    Text("Record all depth data captured during the ARSession and save it to the specified location.").font(.caption2)
                                    Spacer()
                                }
                            }.layoutPriority(1.0)
                            Toggle("", isOn: $saveDepthVideo).onChange(of: saveDepthVideo) { value in
                                ScanConfig.saveDepthVideo = value
                                updateDataEstimate()
                            }.toggleStyle(SwitchToggleStyle(tint: mainColor))
                        }.listRowBackground(Color.clear)
                        HStack {
                            VStack {
                                HStack {
                                    Text("Confidence Data").font(.title3)
                                    Spacer()
                                }
                                HStack {
                                    Text("Record all confidence data captured during the ARSession and save it to the specified location.").font(.caption2)
                                    Spacer()
                                }
                            }.layoutPriority(1.0)
                            Toggle("", isOn: $saveConfidenceVideo).onChange(of: saveConfidenceVideo) { value in
                                ScanConfig.saveConfidenceVideo = value
                                updateDataEstimate()
                            }.toggleStyle(SwitchToggleStyle(tint: mainColor))
                        }.listRowBackground(Color.clear)
                        HStack {
                            VStack {
                                HStack {
                                    Text("ARWorldMap Data").font(.title3)
                                    Spacer()
                                }
                                HStack {
                                    Text("Periodically save all of the ARWorldMap data to a JSON file at the specified location.").font(.caption2)
                                    Spacer()
                                }
                            }.layoutPriority(1.0)
                            Spacer()
                            Toggle("", isOn: $saveWorldMapInfo).onChange(of: saveWorldMapInfo) { value in
                                ScanConfig.saveWorldMapInfo = value
                                updateDataEstimate()
                            }.toggleStyle(SwitchToggleStyle(tint: mainColor))
                        }.listRowBackground(Color.clear)
                        HStack {
                            VStack {
                                HStack {
                                    Text("QR Code Data").font(.title3)
                                    Spacer()
                                }
                                HStack {
                                    Text("Recognize QR Codes and save their location and message in JSON format to the specified location.").font(.caption2)
                                    Spacer()
                                }
                            }.layoutPriority(1.0)
                            Toggle("", isOn: $detectQRCodes).onChange(of: detectQRCodes) { value in
                                ScanConfig.detectQRCodes = value
                                updateDataEstimate()
                            }.toggleStyle(SwitchToggleStyle(tint: mainColor))
                        }.listRowBackground(Color.clear)
                    }
                }
                ThickDivider()
                VStack(spacing: 10) {
                    Text(dataRateText).font(.title3).onAppear() {
                        updateDataEstimate()
                    }
                    Button("Start Scanning") {
                        isPresentingScan.toggle()
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
                    }.buttonStyle(GrowingButton()).fullScreenCover(isPresented: $isPresentingScan) {
                        ScanVC_representable().ignoresSafeArea(.all)
                    }
                    HStack {
                        Button("About") {
                            isPresentingAbout.toggle()
                        }.buttonStyle(GrowingButton()).sheet(isPresented: $isPresentingAbout) {
                            AboutSUIV()
                        }
                        Spacer()
                        Button("Projects") {
                            isPresentingProjects.toggle()
                        }.buttonStyle(GrowingButton()).sheet(isPresented: $isPresentingProjects) {
                            ProjectsSUIV()
                        }
                    }
                }.padding(.top, 10).padding(.leading, 20).padding(.trailing, 20).padding(.bottom, 30) // Button Block end
            }.frame(
                minWidth: 0,
                maxWidth: 500,
                minHeight: 0,
                maxHeight: 900,
                alignment: .topLeading
            ).padding(.top).padding(.leading).padding(.trailing).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16.0)).ignoresSafeArea(.all)
        }.environment(\.colorScheme, .dark)
    }
}

struct SetupSUIV_Previews: PreviewProvider {
    static var previews: some View {
        SetupSUIV()
    }
}
