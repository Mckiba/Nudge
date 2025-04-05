//
//  CameraTrackingManager.swift
//  Tracky
//
//  Created by McKiba Williams on 4/5/25.
//

import AVFoundation
import Vision
import CoreImage

// MARK: - Camera Tracking Manager

class CameraTrackingManager: NSObject, ObservableObject {
    @Published var isEnabled: Bool = false
    @Published var isFaceDetected: Bool = false
    @Published var isLookingAtScreen: Bool = false
    @Published var isHoldingPhone: Bool = false
    @Published var processingActive: Bool = false
    
    private var captureSession: AVCaptureSession?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var captureQueue = DispatchQueue(label: "cameraCaptureQueue")
    private var processingQueue = DispatchQueue(label: "visionProcessingQueue")
    private var lastProcessingTime = Date()
    private var faceDetectionRequest: VNDetectFaceRectanglesRequest?
    private var humanDetectionRequest: VNDetectHumanRectanglesRequest?
    private var handPoseRequest: VNDetectHumanHandPoseRequest?
    
    override init() {
        super.init()
        setupVision()
    }
    
    private func setupVision() {
        // Initialize Vision requests
        faceDetectionRequest = VNDetectFaceRectanglesRequest()
        humanDetectionRequest = VNDetectHumanRectanglesRequest()
        handPoseRequest = VNDetectHumanHandPoseRequest()
        handPoseRequest?.maximumHandCount = 2
    }
    
    func requestPermissionAndSetup(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self = self else { return }
            
            if granted {
                DispatchQueue.main.async {
                    self.setupCaptureSession()
                    self.isEnabled = true
                    completion(true)
                }
            } else {
                DispatchQueue.main.async {
                    self.isEnabled = false
                    completion(false)
                }
            }
        }
    }
    
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .medium
        
        guard let captureSession = captureSession else { return }
        
        // Find front camera
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("Front camera not available")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: frontCamera)
            
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            // Setup video output
            videoDataOutput = AVCaptureVideoDataOutput()
            videoDataOutput?.alwaysDiscardsLateVideoFrames = true
            videoDataOutput?.setSampleBufferDelegate(self, queue: captureQueue)
            
            if let videoDataOutput = videoDataOutput, captureSession.canAddOutput(videoDataOutput) {
                captureSession.addOutput(videoDataOutput)
            }
            
            // Start capture session in background
            captureQueue.async { [weak self] in
                self?.captureSession?.startRunning()
            }
        } catch {
            print("Error setting up camera: \(error.localizedDescription)")
        }
    }
    
    func startTracking() {
        guard isEnabled else {
            requestPermissionAndSetup { success in
                if success {
                    self.processingActive = true
                }
            }
            return
        }
        
        processingActive = true
        captureQueue.async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func stopTracking() {
        processingActive = false
        captureQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
    
    func toggleTracking() {
        if processingActive {
            stopTracking()
        } else {
            startTracking()
        }
    }
    
    private func processFrame(_ pixelBuffer: CVPixelBuffer) {
        // Limit processing to every 1 second to reduce CPU usage
        let now = Date()
        guard now.timeIntervalSince(lastProcessingTime) >= 1.0 else { return }
        lastProcessingTime = now
        
        // Skip processing if not active
        guard processingActive else { return }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        
        processingQueue.async { [weak self] in
            guard let self = self,
                  let faceDetectionRequest = self.faceDetectionRequest,
                  let handPoseRequest = self.handPoseRequest else { return }
            
            do {
                // Run face detection
                try imageRequestHandler.perform([faceDetectionRequest])
                
                DispatchQueue.main.async {
                    // Update face detection status
                    if let results = faceDetectionRequest.results, !results.isEmpty {
                        self.isFaceDetected = true
                        
                        // Simplified logic: if a face is detected centered in frame, assume looking at screen
                        if let faceObservation = results.first {
                            let faceBox = faceObservation.boundingBox
                            let centerX = faceBox.midX
                            let centerY = faceBox.midY
                            
                            // If face is roughly centered, consider as looking at screen
                            self.isLookingAtScreen = (centerX > 0.4 && centerX < 0.6 &&
                                                      centerY > 0.4 && centerY < 0.6)
                        }
                    } else {
                        self.isFaceDetected = false
                        self.isLookingAtScreen = false
                    }
                }
                
                // Run hand pose detection
                try imageRequestHandler.perform([handPoseRequest])
                
                DispatchQueue.main.async {
                    // Update hand detection status
                    if let results = handPoseRequest.results, !results.isEmpty {
                        // Simplified logic: if hand is detected in specific position, assume holding phone
                        // This is a simplified heuristic - real phone detection would need more complex analysis
                        if results.count > 0 {
                            let wristPoints = results.compactMap { observation -> CGPoint? in
                                guard let wristPoint = try? observation.recognizedPoint(.wrist) else { return nil }
                                return wristPoint.location
                            }
                            
                            // If wrist points are detected at certain height (upper part of frame),
                            // assume the user might be holding a phone
                            self.isHoldingPhone = wristPoints.contains { point in
                                return point.y > 0.6 && point.y < 0.9 // Upper middle of frame
                            }
                        } else {
                            self.isHoldingPhone = false
                        }
                    } else {
                        self.isHoldingPhone = false
                    }
                }
                
            } catch {
                print("Vision error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraTrackingManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard processingActive,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        processFrame(pixelBuffer)
    }
}

