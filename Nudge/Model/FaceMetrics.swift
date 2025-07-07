import Foundation
import Vision

struct FaceMetrics {
    let timestamp: Date
    let faceDetected: Bool
    let boundingBox: CGRect
    let leftEyeOpenness: Float
    let rightEyeOpenness: Float
    let eyeOpenness: Float
    let blinkRate: Double
    let gazeDirection: GazeDirection
    let headPose: HeadPose
    let confidence: Float
    let landmarks: VNFaceLandmarks2D?
    
    init(
        timestamp: Date = Date(),
        faceDetected: Bool = false,
        boundingBox: CGRect = .zero,
        leftEyeOpenness: Float = 0.0,
        rightEyeOpenness: Float = 0.0,
        eyeOpenness: Float = 0.0,
        blinkRate: Double = 0.0,
        gazeDirection: GazeDirection = .unknown,
        headPose: HeadPose = .frontal,
        confidence: Float = 0.0,
        landmarks: VNFaceLandmarks2D? = nil
    ) {
        self.timestamp = timestamp
        self.faceDetected = faceDetected
        self.boundingBox = boundingBox
        self.leftEyeOpenness = leftEyeOpenness
        self.rightEyeOpenness = rightEyeOpenness
        self.eyeOpenness = eyeOpenness
        self.blinkRate = blinkRate
        self.gazeDirection = gazeDirection
        self.headPose = headPose
        self.confidence = confidence
        self.landmarks = landmarks
    }
}

enum GazeDirection: String, Codable, CaseIterable {
    case center = "center"
    case left = "left"
    case right = "right"
    case up = "up"
    case down = "down"
    case upLeft = "up_left"
    case upRight = "up_right"
    case downLeft = "down_left"
    case downRight = "down_right"
    case unknown = "unknown"
}

enum HeadPose: String, Codable, CaseIterable {
    case frontal = "frontal"
    case leftProfile = "left_profile"
    case rightProfile = "right_profile"
    case turnedLeft = "turned_left"
    case turnedRight = "turned_right"
    case tilted = "tilted"
    case unknown = "unknown"
}

extension FaceMetrics {
    var isAttentive: Bool {
        guard faceDetected else { return false }
        
        let eyeThreshold: Float = 0.3
        let confidenceThreshold: Float = 0.7
        
        return eyeOpenness > eyeThreshold && 
               confidence > confidenceThreshold &&
               gazeDirection == .center
    }
    
    var attentionScore: Double {
        guard faceDetected else { return 0.0 }
        
        // Ensure eyeOpenness is valid
        let validEyeOpenness = eyeOpenness.isFinite ? eyeOpenness : 0.0
        let eyeScore = Double(min(validEyeOpenness * 2.0, 1.0))
        
        let gazeScore = gazeDirection == .center ? 1.0 : 0.5
        
        // Ensure confidence is valid
        let validConfidence = confidence.isFinite ? confidence : 0.0
        let confidenceScore = Double(max(0.0, min(validConfidence, 1.0)))
        
        let result = (eyeScore + gazeScore + confidenceScore) / 3.0
        
        // Ensure result is valid
        return result.isFinite ? max(0.0, min(result, 1.0)) : 0.0
    }
}