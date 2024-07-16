//
//  VideoFeedVM .swift
//  Tracky
//
//  Created by McKiba Williams on 7/12/24.
//

import Foundation
import AppKit
import Cocoa
import AVFoundation
import SwiftUI
import Vision



//class VideoFeedController: NSViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
//    
//    private var permissionGranted = false
//    
//    private let captureSession = AVCaptureSession()
//    private let sessionQueue = DispatchQueue(label: "sessionQueue")
//    
//    private var previewLayer = AVCaptureVideoPreviewLayer()
//    var screenRect: CGRect! = nil //for view dimension
//    
//    
//    override func viewDidLoad() {
//        checkPermission()
//        
//        sessionQueue.async {
//            [unowned self] in
//            guard permissionGranted else {return}
//            self.setupCaptureSession()
//            self.captureSession.startRunning()
//        }
//    }
//    
//    
//    func checkPermission() {
//        switch AVCaptureDevice.authorizationStatus(for: .video){
//            
//        case .authorized:
//            permissionGranted = true
//            
//        case .notDetermined:
//            requestPermission()
//            
//        default:
//            permissionGranted = false
//        }
//    }
//    
//    func requestPermission() {
//        sessionQueue.suspend()
//        AVCaptureDevice.requestAccess(for: .video, completionHandler: {[unowned self] granted in
//            self.permissionGranted = granted
//            self.sessionQueue.resume()
//        })
//        
//    }
//    
//    func setupCaptureSession(){
//        
//        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified) else {return}
//        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {return}
//        
//        guard captureSession.canAddInput(videoDeviceInput) else {return}
//        captureSession.addInput(videoDeviceInput)
//        
//        
//        //preview Layer
//        screenRect = NSScreen.main?.frame
//        
//        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
//        previewLayer.frame = CGRect(x: 0, y:0 , width: screenRect.size.width, height: screenRect.size.height)
//        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
//        
//        previewLayer.connection?.videoRotationAngle = 0
//        
//        DispatchQueue.main.async {
//            [weak self] in
//            self!.view.layer?.addSublayer(self!.previewLayer)
//        }
//        
//        
//    }
//    
//}
//
//struct HostedViewController: NSViewControllerRepresentable {
//    func makeNSViewController(context: Context) -> NSViewController {
//        return VideoFeedController()
//    }
//    
//    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {
//        // Update the NSViewController's state here
//    }
//}
//
//
//
//
////struct HostedViewController: NSViewRepresentable {
////    func makeUIViewCOntroller(context: Context) -> NSViewController {
////        return VideoFeedController()
////    }
////    
////    func updateUIViewController(_ uiViewController: NSWindowController, context: Context){
////        
////    }
////}





class VideoFeedController: NSViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var permissionGranted = false // Flag for permission
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private var previewLayer = AVCaptureVideoPreviewLayer()
    var screenRect: CGRect! = nil // For view dimensions
    
    // Detector
    private var videoOutput = AVCaptureVideoDataOutput()
    var requests = [VNRequest]()
    var detectionLayer: CALayer! = nil
    
      
    override func viewDidLoad() {
        checkPermission()
        
        sessionQueue.async { [unowned self] in
            guard permissionGranted else { return }
            self.setupCaptureSession()
            
            
            self.captureSession.startRunning()
        }
    }

//    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
//        screenRect = UIScreen.main.bounds
//        self.previewLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
//
//        switch UIDevice.current.orientation {
//            // Home button on top
//            case UIDeviceOrientation.portraitUpsideDown:
//                self.previewLayer.connection?.videoOrientation = .portraitUpsideDown
//             
//            // Home button on right
//            case UIDeviceOrientation.landscapeLeft:
//                self.previewLayer.connection?.videoOrientation = .landscapeRight
//            
//            // Home button on left
//            case UIDeviceOrientation.landscapeRight:
//                self.previewLayer.connection?.videoOrientation = .landscapeLeft
//             
//            // Home button at bottom
//            case UIDeviceOrientation.portrait:
//                self.previewLayer.connection?.videoOrientation = .portrait
//                
//            default:
//                break
//            }
//        
//        // Detector
//        updateLayers()
//    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            // Permission has been granted before
            case .authorized:
                permissionGranted = true
                
            // Permission has not been requested yet
            case .notDetermined:
                requestPermission()
                    
            default:
                permissionGranted = false
            }
    }
    
    func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: .video) { [unowned self] granted in
            self.permissionGranted = granted
            self.sessionQueue.resume()
        }
    }
    
    func setupCaptureSession() {
        // Camera input
        guard let videoDevice = AVCaptureDevice.default(.deskViewCamera,for: .video, position: .back) else { return }
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
           
        guard captureSession.canAddInput(videoDeviceInput) else { return }
        captureSession.addInput(videoDeviceInput)
                         
        // Preview layer
        screenRect = NSScreen.main?.frame
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill // Fill screen
        previewLayer.connection?.videoOrientation = .portrait
        
        // Detector
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sampleBufferQueue"))
        captureSession.addOutput(videoOutput)
        
        videoOutput.connection(with: .video)?.videoOrientation = .portrait
        
        // Updates to UI must be on main queue
        DispatchQueue.main.async { [weak self] in
            self!.view.layer?.addSublayer(self!.previewLayer)
        }
    }
}

struct HostedViewController: NSViewControllerRepresentable {
        func makeNSViewController(context: Context) -> NSViewController {
        return VideoFeedController()
        }

        func updateNSViewController(_ nsViewController: NSViewController, context: Context) {
        }
}
