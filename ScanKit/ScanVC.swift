//
//  RawDataVC.swift
//  ScanKit
//
//  Created by Kenneth Schröder on 11.08.21.
//

import UIKit
import Metal
import MetalKit
import ARKit
import Progress

class ScanVC: UIViewController, MTKViewDelegate, ProgressTracker, CLLocationManagerDelegate {
    @IBOutlet weak var underlayControl: UISegmentedControl!
    @IBOutlet weak var viewControl: UISegmentedControl!
    @IBOutlet weak var viewshedButton: RoundedButton!
    @IBOutlet weak var torchButton: RoundedButton!
    @IBOutlet weak var recordButton: RecordButton!
    @IBOutlet weak var memoryBar: UIProgressView!
    @IBOutlet weak var backButton: UIButton!
    var memoryBarTimer = Timer()
    
    var ar_session: ARSession!
    var renderer: ScanRenderer!
    var ar_manager: ARManager!
    
    var currentProgressRaw: Float = 0
    var currentProgressPC: Float = 0
    
    let locationManager = CLLocationManager()
    var scanLocation: CLLocation?
    var scanStart: TimeInterval!
    var scanEnd: TimeInterval!
    var referencePoints: [Float3] = []
    
    let jsonEncoder = JSONEncoder()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ar_manager = ARManager(viewController: self)
        // Set the view's delegate
        ar_session = ARSession()
        ar_session.delegate = ar_manager
        
        // Set the view to use the default device
        if let view = self.view as? MTKView {
            view.device = MTLCreateSystemDefaultDevice()
            view.backgroundColor = UIColor.clear
            view.delegate = self
            
            guard view.device != nil else {
                print("Metal is not supported on this device")
                return
            }
            
            // Configure the renderer to draw to the view
            renderer = ScanRenderer(session: ar_session, metalDevice: view.device!, renderDestination: view)
            
            renderer.drawRectResized(size: view.bounds.size)
        }
        
        // update UI according to ScanConfig
        underlayControl.selectedSegmentIndex = ScanConfig.underlayIndex
        viewControl.selectedSegmentIndex = ScanConfig.viewIndex
        if ScanConfig.viewshedActive {
            viewshedButton.backgroundColor = UIColor(named: "Occa")
        } else {
            viewshedButton.backgroundColor = .darkGray
        }
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(ScanVC.handleLongPress(gestureRecognizer:)))//UITapGestureRecognizer(target: self, action: #selector(ScanVC.handleTap(gestureRecognizer:)))
        view.addGestureRecognizer(longPressGesture)
        
        self.memoryBarTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
            let _ = self.updateMemoryBarAskContinue()
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = .sceneDepth // additional options like .personSegmentation for green-screen scenarios e.g.
        // smoothedSceneDepth minimizes differences across frames https://developer.apple.com/documentation/arkit/arconfiguration/3089121-framesemantics

        // configuration.isAutoFocusEnabled // camera using fixed focus or auto focus
        configuration.planeDetection = [.horizontal, .vertical] // enabling plane detection smoothes the mesh at points that are near detected planes
        configuration.sceneReconstruction = .meshWithClassification // enables mesh generation
        // configuration.userFaceTrackingEnabled // provides ARFaceAnchor for rendering avatars in multi-user experiences e.g.
        // worldAlignment defines the orientation of the world coordinate system according to gravity vector and compass direction
        configuration.worldAlignment = .gravity // leads to major drift in world tracking when heading enabled
        configuration.environmentTexturing = .none // .automatic

        // Run the view's session
        ar_session.run(configuration)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // ask for location authorisation from the user
        self.locationManager.requestWhenInUseAuthorization()

        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if ScanConfig.isRecording {
            ar_manager.stopRecording(notify: self)
            renderer.stopRecording(notify: self)
            showProgressRing()
            recordButton.backgroundColor = UIColor.green
        } else {
            if scanStart == nil,
               let url = ScanConfig.url { // clean up folder if nothing recorded
                try? FileManager.default.removeItem(at: url)
            }
        }
        ScanConfig.isRecording = false
        
        // Pause the view's session
        ar_session.pause()
    }
    
    // Auto-hide the home indicator to maximize immersion in AR experiences.
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    // Hide the status bar to maximize immersion in AR experiences.
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    public func resetTracking() {
        if let configuration = ar_session.configuration {
            ar_session.run(configuration, options: .resetSceneReconstruction)
        }
    }
    
    // MARK: - interaction handling - reference points
    
    @objc
    func handleLongPress(gestureRecognizer: UILongPressGestureRecognizer) {
        // Create anchor using the camera's current position
        if let currentFrame = ar_session.currentFrame, gestureRecognizer.state == .began {
            let tapLocation = gestureRecognizer.location(in: gestureRecognizer.view)
            let capturedCoordinateSys = view.frame.size
            let norm_point = CGPoint(x: tapLocation.y / capturedCoordinateSys.height, y: 1 - tapLocation.x / capturedCoordinateSys.width)
            
            if let result = ar_session.raycast(currentFrame.raycastQuery(from: norm_point, allowing: .estimatedPlane, alignment: .any)).first {
                referencePoints.append(result.worldTransform.getPositionIfTransform())
                renderer.updateReferencePoints(referencePoints)
            }
        }
    }
    
    // MARK: - MTKViewDelegate
    
    // Called whenever view changes orientation or layout is changed
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer.drawRectResized(size: size)
    }
    
    // Called whenever the view needs to render
    func draw(in view: MTKView) {
        renderer.update()
    }
    
    // MARK: - CLLocationManagerDelegate
    // -> dont care if location changed, its up to the user whether he wants to use this feature
    
    //func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    //
    //}
    
}

// MARK: - UI Methods

extension ScanVC {
    @IBAction func underlayControlChanged(_ sender: UISegmentedControl) {
        ScanConfig.underlayIndex = sender.selectedSegmentIndex
    }
    
    @IBAction func viewControlChanged(_ sender: UISegmentedControl) {
        ScanConfig.viewIndex = sender.selectedSegmentIndex
        if ScanConfig.viewIndex > 0 {
            underlayControl.selectedSegmentIndex = 0
            ScanConfig.underlayIndex = 0
            underlayControl.isEnabled = false
        } else {
            underlayControl.isEnabled = true
        }
    }
    
    @IBAction func viewshed_button_pressed(_ sender: RoundedButton) {
        ScanConfig.viewshedActive = !ScanConfig.viewshedActive
        if ScanConfig.viewshedActive {
            sender.backgroundColor = UIColor(named: "Occa")
        } else {
            sender.backgroundColor = .darkGray
        }
    }
    
    // https://stackoverflow.com/questions/27207278/how-to-turn-flashlight-on-and-off-in-swift
    @IBAction func torch_button_pressed(_ sender: RoundedButton) {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        guard device.hasTorch else { return }

        do {
            try device.lockForConfiguration()

            if (device.torchMode == AVCaptureDevice.TorchMode.on) {
                device.torchMode = AVCaptureDevice.TorchMode.off
                sender.backgroundColor = .darkGray
            } else {
                do {
                    try device.setTorchModeOn(level: 1.0)
                    sender.backgroundColor = UIColor(named: "Occa")
                } catch {
                    print(error)
                }
            }

            device.unlockForConfiguration()
        } catch {
            print(error)
        }
    }
    
    func beginRecording() {
        backButton.isEnabled = false
        scanLocation = locationManager.location
        scanStart = NSDate().timeIntervalSince1970
        recordButton.layer.backgroundColor = UIColor.red.cgColor
        ScanConfig.isRecording = true
    }
    
    func finishRecording() {
        scanEnd = NSDate().timeIntervalSince1970
        let meta = ScanMetaData(location: scanLocation, startTime: scanStart, endTime: scanEnd, referencePoints: referencePoints)
        if let url = ScanConfig.url {
            if let metaData = try? self.jsonEncoder.encode(meta) {
                do {
                    try metaData.write(to: url.appendingPathComponent("metadata.json"), options: .atomic)
                } catch {
                    print("Writing metadata json file failed.")
                    print(error.localizedDescription)
                }
            }
        }
        
        ar_manager.stopRecording(notify: self)
        renderer.stopRecording(notify: self)
        showProgressRing()
        backButton.isEnabled = true
        recordButton.layer.backgroundColor = UIColor.green.cgColor
        ScanConfig.isRecording = false
    }
    
    @IBAction func record_button_pressed(_ sender: RoundedButton) {
        if ScanConfig.isRecording {
            finishRecording()
        } else {
            beginRecording()
        }
    }
    
    @IBAction func back_button_pressed(_ sender: RoundedButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Progress indicator
    
    func showProgressRing() {
        let ringParam: RingProgressorParameter = (.proportional, UIColor.green.withAlphaComponent(0.4), 100, 50)
        var labelParam: LabelProgressorParameter = DefaultLabelProgressorParameter
        labelParam.font = UIFont.systemFont(ofSize: 30, weight: UIFont.Weight.bold)
        labelParam.color = UIColor.white.withAlphaComponent(0.3)
        DispatchQueue.main.async {
            Prog.start(in: self.view, .blur(.regular), .ring(ringParam), .label(labelParam))
            //self.updateProgress()
        }
        perform(#selector(updateProgress), with: nil, afterDelay: 2.0)
    }
    
    func notifyProgressRaw(value: Float) {
        currentProgressRaw = value
        updateProgress()
    }
    func notifyProgressPC(value: Float) {
        currentProgressPC = value
        updateProgress()
    }
    
    @objc func updateProgress() {
        let value: Float = (currentProgressRaw + currentProgressPC) / 2.0
        
        DispatchQueue.main.async {
            Prog.update(value, in: self.view)
        }
        if value >= 1.0 || value.isNaN {
            usleep(600_000) // sleep mills to not break Prog
            DispatchQueue.main.async {
                Prog.end(in: self.view)
            }
        }
    }
    
    // MARK: - Memory Bar
    
    func updateMemoryBarAskContinue() -> Bool {
        memoryBar.progress = Float(query_memory())/5_000_000_000
        if memoryBar.progress < 0.5 {
            memoryBar.tintColor = .green
        } else if memoryBar.progress < 0.75 {
            memoryBar.tintColor = .orange
        } else {
            memoryBar.tintColor = .red
            return false
        }
        return true
    }
    
    func query_memory() -> UInt64 {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return taskInfo.resident_size
        } else {
            print("Error with task_info(): " +
                (String(cString: mach_error_string(kerr), encoding: String.Encoding.ascii) ?? "unknown error"))
            return 0
        }
    }
}
