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

class RecorderVC: UIViewController, MTKViewDelegate {
    @IBOutlet weak var underlayControl: UISegmentedControl!
    
    var ar_session: ARSession!
    var renderer: ScanRenderer!
    var ar_manager: ARManager!
    
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
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(RecorderVC.handleTap(gestureRecognize:)))
        view.addGestureRecognizer(tapGesture)
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
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
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
    
    // MARK: - interaction handling
    
    @objc
    func handleTap(gestureRecognize: UITapGestureRecognizer) {
        // Create anchor using the camera's current position
        if let currentFrame = ar_session.currentFrame {
            // TODO create viewpoints on tap?
            
            // Create a transform with a translation of 0.2 meters in front of the camera
            //var translation = matrix_identity_float4x4
            //translation.columns.3.z = -0.2
            //let transform = simd_mul(currentFrame.camera.transform, translation)
            
            // Add a new anchor to the session
            //let anchor = ARAnchor(transform: transform)
            //ar_session.add(anchor: anchor)
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
}

// MARK: - UI Methods

extension RecorderVC {
    @IBAction func underlayControlChanged(_ sender: UISegmentedControl) {
        ScanConfig.underlayIndex = underlayControl.selectedSegmentIndex
    }
}
