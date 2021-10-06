//
//  ProjectDetailsSUIV.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 29.09.21.
//

import SwiftUI
import MapKit

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

struct ProjectDetailsSUIV: View {
    var projectName: String
    var metaDataP: ScanMetaDataPrintable
    
    init(projectName: String) {
        self.projectName = projectName
        self.metaDataP = getMetaData(projectName)
    }
    
    var body: some View {
        VStack {
            List {
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
                                MapPin(coordinate: item, tint: .red)
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
            }
            Button("Open in Files App") { // https://stackoverflow.com/questions/64591298/how-can-i-open-default-files-app-with-myapp-folder-programmatically
                func getDocumentsDirectory() -> URL { // returns your application folder
                    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                    let documentsDirectory = paths[0]
                    return documentsDirectory
                }
                let projectURL = getDocumentsDirectory().appendingPathComponent(projectName)
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
