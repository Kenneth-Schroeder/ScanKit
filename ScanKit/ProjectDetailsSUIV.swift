//
//  ProjectDetailsSUIV.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 29.09.21.
//

import SwiftUI
import MapKit
import NMSSH

func getMetaData(_ projectName: String) -> ScanMetaDataPrintable {
    let jsonDecoder = JSONDecoder()
    let filemgr = FileManager.default
    let dirPaths = filemgr.urls(for: .documentDirectory, in: .userDomainMask)
    let myDocumentsDirectory = dirPaths[0]
    let projectDir = myDocumentsDirectory.appendingPathComponent(projectName)
    let metaFilePath = projectDir.appendingPathComponent("metadata.json")
    var md: ScanMetaData? = nil
    
    do {
        let data = try Data(contentsOf: metaFilePath)

        if let jsonMeta = try? jsonDecoder.decode(ScanMetaData.self, from: data) {
            md = jsonMeta
        }
    } catch {
        print("Reading meta data failed!")
    }
    
    return ScanMetaDataPrintable(fromScanMetaData: md)
}

func getProjectsDirectory(_ projectName: String) -> URL { // returns your application folder
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    let documentsDirectory = paths[0]
    return documentsDirectory.appendingPathComponent(projectName)
}

struct ProjectDetailsSUIV: View {
    var projectName: String
    var metaDataP: ScanMetaDataPrintable
    var dirSize: String = "calculation failed"
    @State private var sftpServer: String = ""
    @State private var sftpPort: Int?
    @State private var sftpUser: String = ""
    @State private var sftpPassword: String = ""
    @State private var sftpFolder: String = ""
    @State private var sftpProgress = 0.0
    @State private var isUploading = false
    @State private var isShowingFailure = false
    
    
    init(projectName: String) {
        self.projectName = projectName
        self.metaDataP = getMetaData(projectName)
        let fm = FileManager()
        do {
            let size = try fm.allocatedSizeOfDirectory(at: getProjectsDirectory(projectName))
            let bcf = ByteCountFormatter()
            self.dirSize = bcf.string(fromByteCount: Int64(size))
        } catch let error {
            print("Failed to calculate project directory size, error \(error)")
        }
    }
    
    func uploadSFPT(host: String, port: Int?, user: String, pw: String, projectName: String, projectLocalUrl: URL, uploadFolder: String? = "", deleteLocal: Bool = false) {
        //let deviceID = UIDevice.current.identifierForVendor!.uuidString
        let theUploadFolder = (uploadFolder ?? "");
        
        if theUploadFolder.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) != nil {
            NSLog("Upload folder is not allowed to contain special characters!")
            self.isShowingFailure = true
            return
        }
        
        let sftpQueue = DispatchQueue(label: "sftp-queue", qos: .utility)
        do {
            let projectFiles = try FileManager.default.contentsOfDirectory(at: projectLocalUrl, includingPropertiesForKeys: nil)
            sftpQueue.async {
                var session: NMSSHSession
                if let p = port {
                    session = NMSSHSession.init(host: host, port: p, andUsername: user)
                } else {
                    session = NMSSHSession.init(host: host, andUsername: user)
                }
                
                session.connect()
                if session.isConnected {
                    session.authenticate(byPassword: pw)
                    if session.isAuthorized == true {
                        let sftpsession = NMSFTP(session: session)
                        
                        sftpsession.connect()
                        if sftpsession.isConnected {
                            
                            if !theUploadFolder.isEmpty && !sftpsession.directoryExists(atPath: theUploadFolder) {
                                NSLog("Trying to create upload folder %s ...", theUploadFolder)
                                sftpsession.createDirectory(atPath: theUploadFolder)
                            }
                            
                            self.isUploading = true
                            for (idx, filePath) in projectFiles.enumerated() {
                                let deviceDir = projectName
                                
                                let deviceFolder = (theUploadFolder.isEmpty ? "" : theUploadFolder + "/" ) + deviceDir;
                                if !sftpsession.directoryExists(atPath: deviceFolder) {
                                    print("trying to create folder")
                                    sftpsession.createDirectory(atPath: deviceFolder)
                                }
                                sftpsession.writeFile(atPath: filePath.relativePath, toFileAtPath: deviceFolder + "/" + filePath.lastPathComponent)
                                
                                print("Finished copying " + filePath.lastPathComponent + " to sftp server!")
                                if deleteLocal {
                                    print("Deleting local copy of transfered file")
                                    do { try FileManager.default.removeItem(at: filePath) } catch { print("Error when trying to delete local file: \(error)") }
                                }
                                
                                self.sftpProgress = Double(idx+1) / Double(projectFiles.count)
                            }
                        } else {
                            self.isShowingFailure = true
                        }
                    } else {
                        self.isShowingFailure = true
                    }
                } else {
                    print("Couldn't connect to sftp server! Files not copied.")
                    self.isShowingFailure = true
                }
                session.disconnect()
                self.isUploading = false
            }
        } catch {
            print(error)
            self.isShowingFailure = true
            self.isUploading = false
            return
        }
    }
    
    var body: some View {
        VStack {
            List {
                Section(header: Text("Storage")) {
                    HStack {
                        Text("Project Size")
                        Spacer()
                        Text(String(dirSize))
                    }
                }
                Section(header: Text("Time")) {
                    HStack {
                        Text("Scan Start")
                        Spacer()
                        Text(metaDataP.scanStart)
                    }
                    HStack {
                        Text("Scan End")
                        Spacer()
                        Text(metaDataP.scanEnd)
                    }
                }
                Section(header: Text("Location")) {
                    HStack {
                        Text("Latitude")
                        Spacer()
                        Text(metaDataP.latitude)
                    }
                    HStack {
                        Text("Longitude")
                        Spacer()
                        Text(metaDataP.longitude)
                    }
                    if let lat = metaDataP.latitudePrecise,
                        let lon = metaDataP.longitudePrecise {
                        let location2D = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        let span = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                        
                        Map(coordinateRegion: .constant(MKCoordinateRegion(center: location2D, span: span)), showsUserLocation: false, annotationItems: [location2D]) { item in
                                MapMarker(coordinate: item, tint: .red)
                        }
                        .frame(height: 300)
                    }
                }
                Section(header: Text("Settings")) {
                    HStack {
                        Text("Save Point Cloud")
                        Spacer()
                        Text(metaDataP.savePointCloud)
                    }
                    HStack {
                        Text("Save RGB Video")
                        Spacer()
                        Text(metaDataP.saveRGBVideo)
                    }
                    HStack {
                        Text("RGB Quality")
                        Spacer()
                        Text(metaDataP.rgbQuality)
                    }
                    HStack {
                        Text("Save Depth Data")
                        Spacer()
                        Text(metaDataP.saveDepthVideo)
                    }
                    HStack {
                        Text("Save Confidence Data")
                        Spacer()
                        Text(metaDataP.saveConfidenceVideo)
                    }
                    HStack {
                        Text("Save ARWorldMap")
                        Spacer()
                        Text(metaDataP.saveWorldMapInfo)
                    }
                    HStack {
                        Text("Detect QR Codes")
                        Spacer()
                        Text(metaDataP.detectQRCodes)
                    }
                }
                Section(header: Text("SFTP Upload")) {
                    HStack {
                        Text("Host")
                        Spacer()
                        TextField("Server IP", text: $sftpServer)
                    }
                    HStack {
                        Text("Port")
                        Spacer()
                        TextField("Server Port", value: $sftpPort, formatter: NumberFormatter()).keyboardType(.numberPad)
                    }
                    HStack {
                        Text("Username")
                        Spacer()
                        TextField("Username", text: $sftpUser)
                    }
                    HStack {
                        Text("Password")
                        Spacer()
                        TextField("Password", text: $sftpPassword)
                    }
                    HStack {
                        Text("Folder")
                        Spacer()
                        TextField("Folder", text: $sftpFolder ,prompt: Text("Subfolder on Server"))
                    }
                    HStack {
                        Spacer()
                        if isUploading && !isShowingFailure {
                            ProgressView(value: sftpProgress, total: 1.0).scaleEffect(x: 1, y: 4, anchor: .center)
                        } else {
                            Button("Upload") {
                                uploadSFPT(host: sftpServer, port: sftpPort, user: sftpUser, pw: sftpPassword, projectName: projectName, projectLocalUrl: getProjectsDirectory(projectName), uploadFolder: sftpFolder)
                            }.alert(isPresented: $isShowingFailure) {
                                Alert(title: Text("Starting Upload failed!"), message: Text("Please check your SFTP configuration and make sure not to use special characters in the folder input field."), dismissButton: .default(Text("Got it!")))
                            }
                        }
                        Spacer()
                    }
                }
            }
            Button("Open in Files App") { // https://stackoverflow.com/questions/64591298/how-can-i-open-default-files-app-with-myapp-folder-programmatically
                let projectURL = getProjectsDirectory(projectName)
                let path = projectURL.absoluteString.replacingOccurrences(of: "file://", with: "shareddocuments://")
                let url = URL(string: path)!
                UIApplication.shared.open(url)
            }
            Spacer()
        }
        .navigationTitle(projectName)
    }
}

struct ProjectDetailsSUIV_Previews: PreviewProvider {
    static var previews: some View {
        ProjectDetailsSUIV(projectName: "PreviewTestTest")
    }
}
