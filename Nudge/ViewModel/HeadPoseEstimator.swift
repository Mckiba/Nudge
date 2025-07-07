import Foundation
import Vision

class HeadPoseEstimator {
    private let poseHistory: NSMutableArray = NSMutableArray()
    private let historySize = 5
    
    func estimateHeadPose(from faceObservation: VNFaceObservation) -> HeadPose {
        let pose = calculateHeadPose(from: faceObservation)
        
        // Add to history for smoothing
        poseHistory.add(pose.rawValue)
        if poseHistory.count > historySize {
            poseHistory.removeObject(at: 0)
        }
        
        return smoothHeadPose() ?? pose
    }
    
    private func calculateHeadPose(from faceObservation: VNFaceObservation) -> HeadPose {
        guard let landmarks = faceObservation.landmarks else { return .unknown }
        
        // Use face bounding box and landmarks to estimate pose
        let boundingBox = faceObservation.boundingBox
        let faceCenter = CGPoint(
            x: boundingBox.midX,
            y: boundingBox.midY
        )
        
        // Analyze facial feature positions relative to face center
        let poseIndicators = analyzeFacialFeaturePositions(landmarks: landmarks, faceCenter: faceCenter)
        
        return classifyHeadPose(from: poseIndicators)
    }
    
    private func analyzeFacialFeaturePositions(landmarks: VNFaceLandmarks2D, faceCenter: CGPoint) -> HeadPoseIndicators {
        var indicators = HeadPoseIndicators()
        
        // Analyze nose position
        if let nose = landmarks.nose {
            let nosePoints = nose.normalizedPoints
            if !nosePoints.isEmpty {
                let noseCenter = CGPoint(
                    x: nosePoints.reduce(0) { $0 + $1.x } / CGFloat(nosePoints.count),
                    y: nosePoints.reduce(0) { $0 + $1.y } / CGFloat(nosePoints.count)
                )
                indicators.noseOffset = CGPoint(
                    x: noseCenter.x - faceCenter.x,
                    y: noseCenter.y - faceCenter.y
                )
            }
        }
        
        // Analyze eye positions
        if let leftEye = landmarks.leftEye, let rightEye = landmarks.rightEye {
            let leftEyePoints = leftEye.normalizedPoints
            let rightEyePoints = rightEye.normalizedPoints
            
            if !leftEyePoints.isEmpty && !rightEyePoints.isEmpty {
                let leftEyeCenter = CGPoint(
                    x: leftEyePoints.reduce(0) { $0 + $1.x } / CGFloat(leftEyePoints.count),
                    y: leftEyePoints.reduce(0) { $0 + $1.y } / CGFloat(leftEyePoints.count)
                )
                let rightEyeCenter = CGPoint(
                    x: rightEyePoints.reduce(0) { $0 + $1.x } / CGFloat(rightEyePoints.count),
                    y: rightEyePoints.reduce(0) { $0 + $1.y } / CGFloat(rightEyePoints.count)
                )
                
                indicators.eyeLine = CGPoint(
                    x: rightEyeCenter.x - leftEyeCenter.x,
                    y: rightEyeCenter.y - leftEyeCenter.y
                )
                
                // Calculate eye visibility (for profile detection)
                indicators.leftEyeVisibility = calculateEyeVisibility(leftEyePoints)
                indicators.rightEyeVisibility = calculateEyeVisibility(rightEyePoints)
            }
        }
        
        // Analyze mouth position
        if let outerLips = landmarks.outerLips {
            let lipPoints = outerLips.normalizedPoints
            if !lipPoints.isEmpty {
                let mouthCenter = CGPoint(
                    x: lipPoints.reduce(0) { $0 + $1.x } / CGFloat(lipPoints.count),
                    y: lipPoints.reduce(0) { $0 + $1.y } / CGFloat(lipPoints.count)
                )
                indicators.mouthOffset = CGPoint(
                    x: mouthCenter.x - faceCenter.x,
                    y: mouthCenter.y - faceCenter.y
                )
            }
        }
        
        return indicators
    }
    
    private func calculateEyeVisibility(_ eyePoints: [CGPoint]) -> Float {
        guard eyePoints.count >= 6 else { return 0.0 }
        
        // Calculate eye aspect ratio as a measure of visibility
        let leftCorner = eyePoints[0]
        let rightCorner = eyePoints[3]
        let topPoint = eyePoints[1]
        let bottomPoint = eyePoints[5]
        
        let horizontalDistance = abs(rightCorner.x - leftCorner.x)
        let verticalDistance = abs(topPoint.y - bottomPoint.y)
        
        guard horizontalDistance > 0 else { return 0.0 }
        
        return Float(verticalDistance / horizontalDistance)
    }
    
    private func classifyHeadPose(from indicators: HeadPoseIndicators) -> HeadPose {
        let noseThreshold: CGFloat = 0.05
        let eyeVisibilityThreshold: Float = 0.15
        let tiltThreshold: CGFloat = 0.1
        
        // Check for profile poses based on eye visibility
        if indicators.leftEyeVisibility < eyeVisibilityThreshold {
            return .leftProfile
        } else if indicators.rightEyeVisibility < eyeVisibilityThreshold {
            return .rightProfile
        }
        
        // Check for turned poses based on nose position
        if indicators.noseOffset.x > noseThreshold {
            return .turnedRight
        } else if indicators.noseOffset.x < -noseThreshold {
            return .turnedLeft
        }
        
        // Check for tilted pose based on eye line
        if abs(indicators.eyeLine.y) > tiltThreshold {
            return .tilted
        }
        
        return .frontal
    }
    
    private func smoothHeadPose() -> HeadPose? {
        guard poseHistory.count >= 3 else { return nil }
        
        // Count frequency of each pose in recent history
        var frequencyMap: [String: Int] = [:]
        for i in max(0, poseHistory.count - 3)..<poseHistory.count {
            if let pose = poseHistory[i] as? String {
                frequencyMap[pose] = (frequencyMap[pose] ?? 0) + 1
            }
        }
        
        // Return the most frequent pose
        let mostFrequent = frequencyMap.max { $0.value < $1.value }
        if let key = mostFrequent?.key {
            return HeadPose(rawValue: key)
        }
        return nil
    }
}

private struct HeadPoseIndicators {
    var noseOffset: CGPoint = .zero
    var eyeLine: CGPoint = .zero
    var mouthOffset: CGPoint = .zero
    var leftEyeVisibility: Float = 1.0
    var rightEyeVisibility: Float = 1.0
}