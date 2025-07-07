import Foundation
import Vision
import AVFoundation
import CoreML
import Combine

class AttentionDetectionEngine: NSObject, ObservableObject {
    @Published var currentFaceMetrics: FaceMetrics = FaceMetrics()
    @Published var isDetecting: Bool = false
    @Published var attentionScore: Double = 0.0
    @Published var confidenceLevel: Float = 0.0
    
    private var captureSession: AVCaptureSession?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var videoDataOutputQueue: DispatchQueue?
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    
    private var faceDetectionRequest: VNDetectFaceLandmarksRequest?
    private var sequenceRequestHandler = VNSequenceRequestHandler()
    
    private var frameCounter = 0
    private let processingInterval = 3 // Process every 3rd frame for Intel Mac optimization
    
    private var blinkDetector = BlinkDetector()
    private var gazeEstimator = GazeEstimator()
    private var headPoseEstimator = HeadPoseEstimator()
    
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        setupVisionRequest()
        // Don't setup capture session automatically - wait for startDetection()
    }
    
    private func setupVisionRequest() {
        faceDetectionRequest = VNDetectFaceLandmarksRequest { [weak self] request, error in
            DispatchQueue.main.async {
                self?.handleFaceDetectionResults(request: request, error: error)
            }
        }
        
        faceDetectionRequest?.revision = VNDetectFaceLandmarksRequestRevision3
    }
    
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .medium // Optimized for Intel Mac
        
        guard let captureSession = captureSession else {
            print("ERROR: Failed to create capture session")
            return
        }
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, 
                                                       for: .video, 
                                                       position: .front) else {
            print("ERROR: Failed to get front camera - no camera available")
            return
        }
        
        print("SUCCESS: Found front camera - \(videoDevice.localizedName)")
        
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if captureSession.canAddInput(videoDeviceInput) {
                captureSession.addInput(videoDeviceInput)
                print("SUCCESS: Added camera input to capture session")
            } else {
                print("ERROR: Cannot add video input to capture session")
                return
            }
            
            videoDataOutput = AVCaptureVideoDataOutput()
            videoDataOutput?.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            videoDataOutput?.alwaysDiscardsLateVideoFrames = true
            videoDataOutput?.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            
            if captureSession.canAddOutput(videoDataOutput!) {
                captureSession.addOutput(videoDataOutput!)
                print("SUCCESS: Added video output to capture session")
            } else {
                print("ERROR: Cannot add video output to capture session")
                return
            }
            
            // Create preview layer
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.videoGravity = .resizeAspectFill
            
            print("SUCCESS: Camera capture session setup complete")
            
        } catch {
            print("ERROR: Failed to set up camera: \(error.localizedDescription)")
        }
    }
    
    func startDetection() {
        // Setup capture session if not already done
        if captureSession == nil {
            setupCaptureSession()
        }
        
        guard let captureSession = captureSession else {
            print("ERROR: Cannot start detection - no capture session")
            return
        }
        
        // Check camera permission
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        guard authStatus == .authorized else {
            print("ERROR: Cannot start detection - camera permission not granted: \(authStatus.rawValue)")
            return
        }
        
        print("Starting camera detection...")
        
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
            
            DispatchQueue.main.async {
                if captureSession.isRunning {
                    self.isDetecting = true
                    print("SUCCESS: Camera detection started - session is running")
                } else {
                    print("ERROR: Camera detection failed to start - session not running")
                }
            }
        }
    }
    
    func stopDetection() {
        captureSession?.stopRunning()
        isDetecting = false
    }
    
    private func handleFaceDetectionResults(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNFaceObservation] else {
            updateFaceMetrics(with: FaceMetrics(faceDetected: false))
            return
        }
        
        guard let face = results.first else {
            updateFaceMetrics(with: FaceMetrics(faceDetected: false))
            return
        }
        
        processFaceObservation(face)
    }
    
    private func processFaceObservation(_ face: VNFaceObservation) {
        let landmarks = face.landmarks
        
        // Calculate eye openness
        let eyeOpenness = calculateEyeOpenness(from: landmarks)
        let leftEyeOpenness = eyeOpenness.left
        let rightEyeOpenness = eyeOpenness.right
        let averageEyeOpenness = (leftEyeOpenness + rightEyeOpenness) / 2.0
        
        // Estimate gaze direction
        let gazeDirection = gazeEstimator.estimateGaze(from: landmarks)
        
        // Estimate head pose
        let headPose = headPoseEstimator.estimateHeadPose(from: face)
        
        // Update blink detection
        blinkDetector.updateWithEyeOpenness(averageEyeOpenness)
        
        let faceMetrics = FaceMetrics(
            timestamp: Date(),
            faceDetected: true,
            boundingBox: face.boundingBox,
            leftEyeOpenness: leftEyeOpenness,
            rightEyeOpenness: rightEyeOpenness,
            eyeOpenness: averageEyeOpenness,
            blinkRate: blinkDetector.currentBlinkRate,
            gazeDirection: gazeDirection,
            headPose: headPose,
            confidence: face.confidence,
            landmarks: landmarks
        )
        
        updateFaceMetrics(with: faceMetrics)
    }
    
    private func calculateEyeOpenness(from landmarks: VNFaceLandmarks2D?) -> (left: Float, right: Float) {
        guard let landmarks = landmarks else { return (0.0, 0.0) }
        
        let leftEyeOpenness = calculateSingleEyeOpenness(landmarks.leftEye)
        let rightEyeOpenness = calculateSingleEyeOpenness(landmarks.rightEye)
        
        return (leftEyeOpenness, rightEyeOpenness)
    }
    
    private func calculateSingleEyeOpenness(_ eyeLandmarks: VNFaceLandmarkRegion2D?) -> Float {
        guard let eyeLandmarks = eyeLandmarks,
              eyeLandmarks.pointCount >= 6 else { return 0.0 }
        
        let points = eyeLandmarks.normalizedPoints
        
        // Calculate vertical distance between upper and lower eyelid
        let upperPoint = points[1]
        let lowerPoint = points[5]
        let verticalDistance = abs(upperPoint.y - lowerPoint.y)
        
        // Calculate horizontal distance for normalization
        let leftPoint = points[0]
        let rightPoint = points[3]
        let horizontalDistance = abs(rightPoint.x - leftPoint.x)
        
        // Prevent division by zero and ensure valid result
        guard horizontalDistance > 0.001 else {
            print("WARNING: Horizontal distance too small (\(horizontalDistance)), returning default eye openness")
            return 0.5 // Default reasonable eye openness
        }
        
        let ratio = Float(verticalDistance / horizontalDistance)
        
        // Ensure the result is a valid number
        guard ratio.isFinite else {
            print("WARNING: Eye openness calculation resulted in non-finite value, returning default")
            return 0.5
        }
        
        // Clamp the result to reasonable bounds
        return max(0.0, min(ratio, 2.0))
    }
    
    private func updateFaceMetrics(with metrics: FaceMetrics) {
        currentFaceMetrics = metrics
        attentionScore = metrics.attentionScore
        confidenceLevel = metrics.confidence
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension AttentionDetectionEngine: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, 
                      didOutput sampleBuffer: CMSampleBuffer, 
                      from connection: AVCaptureConnection) {
        
        frameCounter += 1
        
        // Log first successful frame
        if frameCounter == 1 {
            print("SUCCESS: Receiving camera frames - first frame captured")
        }
        
        // Process only every Nth frame for performance optimization
        guard frameCounter % processingInterval == 0 else { return }
        
        // Log periodic frame processing
        if frameCounter % (processingInterval * 30) == 0 { // Every ~30 processed frames
            print("INFO: Processing frame \(frameCounter / processingInterval) (total frames: \(frameCounter))")
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("ERROR: Failed to get pixel buffer from sample")
            return
        }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, 
                                                       orientation: .leftMirrored, 
                                                       options: [:])
        
        guard let faceDetectionRequest = faceDetectionRequest else {
            print("ERROR: No face detection request available")
            return
        }
        
        do {
            try imageRequestHandler.perform([faceDetectionRequest])
        } catch {
            print("ERROR: Failed to perform face detection: \(error.localizedDescription)")
        }
    }
}