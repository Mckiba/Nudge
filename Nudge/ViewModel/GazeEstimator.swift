import Foundation
import Vision

class GazeEstimator {
    private let gazeHistory: NSMutableArray = NSMutableArray()
    private let historySize = 10
    
    func estimateGaze(from landmarks: VNFaceLandmarks2D?) -> GazeDirection {
        guard let landmarks = landmarks else { return .unknown }
        
        let gazeDirection = calculateGazeDirection(from: landmarks)
        
        // Add to history for smoothing
        gazeHistory.add(gazeDirection.rawValue)
        if gazeHistory.count > historySize {
            gazeHistory.removeObject(at: 0)
        }
        
        return smoothGazeDirection() ?? gazeDirection
    }
    
    private func calculateGazeDirection(from landmarks: VNFaceLandmarks2D) -> GazeDirection {
        guard let leftEye = landmarks.leftEye,
              let rightEye = landmarks.rightEye,
              let leftPupil = landmarks.leftPupil,
              let rightPupil = landmarks.rightPupil else {
            return estimateGazeFromEyePosition(landmarks: landmarks)
        }
        
        // Calculate pupil position relative to eye corners
        let leftEyePoints = leftEye.normalizedPoints
        let rightEyePoints = rightEye.normalizedPoints
        let leftPupilPoints = leftPupil.normalizedPoints
        let rightPupilPoints = rightPupil.normalizedPoints
        
        guard !leftEyePoints.isEmpty && !rightEyePoints.isEmpty &&
              !leftPupilPoints.isEmpty && !rightPupilPoints.isEmpty else {
            return estimateGazeFromEyePosition(landmarks: landmarks)
        }
        
        // Calculate gaze vectors
        let leftGazeVector = calculateEyeGazeVector(eyePoints: leftEyePoints, pupilPoints: leftPupilPoints)
        let rightGazeVector = calculateEyeGazeVector(eyePoints: rightEyePoints, pupilPoints: rightPupilPoints)
        
        // Average the gaze vectors
        let averageGazeX = (leftGazeVector.x + rightGazeVector.x) / 2.0
        let averageGazeY = (leftGazeVector.y + rightGazeVector.y) / 2.0
        
        return classifyGazeDirection(x: averageGazeX, y: averageGazeY)
    }
    
    private func estimateGazeFromEyePosition(landmarks: VNFaceLandmarks2D) -> GazeDirection {
        // Fallback method using basic eye landmark analysis
        guard let leftEye = landmarks.leftEye,
              let rightEye = landmarks.rightEye else { return .unknown }
        
        let leftEyePoints = leftEye.normalizedPoints
        let rightEyePoints = rightEye.normalizedPoints
        
        guard leftEyePoints.count >= 6 && rightEyePoints.count >= 6 else { return .unknown }
        
        // Estimate gaze based on eye shape asymmetry
        let leftEyeAsymmetry = calculateEyeAsymmetry(eyePoints: leftEyePoints)
        let rightEyeAsymmetry = calculateEyeAsymmetry(eyePoints: rightEyePoints)
        
        let averageAsymmetryX = (leftEyeAsymmetry.x + rightEyeAsymmetry.x) / 2.0
        let averageAsymmetryY = (leftEyeAsymmetry.y + rightEyeAsymmetry.y) / 2.0
        
        return classifyGazeDirection(x: averageAsymmetryX, y: averageAsymmetryY)
    }
    
    private func calculateEyeGazeVector(eyePoints: [CGPoint], pupilPoints: [CGPoint]) -> CGPoint {
        guard let pupilCenter = pupilPoints.first else { return CGPoint.zero }
        
        // Calculate eye center
        let eyeCenter = CGPoint(
            x: eyePoints.reduce(0) { $0 + $1.x } / CGFloat(eyePoints.count),
            y: eyePoints.reduce(0) { $0 + $1.y } / CGFloat(eyePoints.count)
        )
        
        // Calculate gaze vector (pupil relative to eye center)
        return CGPoint(
            x: pupilCenter.x - eyeCenter.x,
            y: pupilCenter.y - eyeCenter.y
        )
    }
    
    private func calculateEyeAsymmetry(eyePoints: [CGPoint]) -> CGPoint {
        guard eyePoints.count >= 6 else { return CGPoint.zero }
        
        // Calculate the horizontal and vertical asymmetry of the eye
        let leftCorner = eyePoints[0]
        let rightCorner = eyePoints[3]
        let topPoint = eyePoints[1]
        let bottomPoint = eyePoints[5]
        
        let horizontalCenter = (leftCorner.x + rightCorner.x) / 2.0
        let verticalCenter = (topPoint.y + bottomPoint.y) / 2.0
        
        // Calculate center of all points
        let actualCenter = CGPoint(
            x: eyePoints.reduce(0) { $0 + $1.x } / CGFloat(eyePoints.count),
            y: eyePoints.reduce(0) { $0 + $1.y } / CGFloat(eyePoints.count)
        )
        
        return CGPoint(
            x: actualCenter.x - horizontalCenter,
            y: actualCenter.y - verticalCenter
        )
    }
    
    private func classifyGazeDirection(x: CGFloat, y: CGFloat) -> GazeDirection {
        let threshold: CGFloat = 0.02
        let strongThreshold: CGFloat = 0.05
        
        // Classify based on gaze vector magnitude and direction
        if abs(x) < threshold && abs(y) < threshold {
            return .center
        }
        
        if abs(x) > abs(y) {
            // Horizontal movement is dominant
            if x > strongThreshold {
                return y > threshold ? .upRight : (y < -threshold ? .downRight : .right)
            } else if x < -strongThreshold {
                return y > threshold ? .upLeft : (y < -threshold ? .downLeft : .left)
            }
        } else {
            // Vertical movement is dominant
            if y > strongThreshold {
                return x > threshold ? .upRight : (x < -threshold ? .upLeft : .up)
            } else if y < -strongThreshold {
                return x > threshold ? .downRight : (x < -threshold ? .downLeft : .down)
            }
        }
        
        return .center
    }
    
    private func smoothGazeDirection() -> GazeDirection? {
        guard gazeHistory.count >= 3 else { return nil }
        
        // Count frequency of each gaze direction in recent history
        var frequencyMap: [String: Int] = [:]
        for i in max(0, gazeHistory.count - 5)..<gazeHistory.count {
            if let direction = gazeHistory[i] as? String {
                frequencyMap[direction] = (frequencyMap[direction] ?? 0) + 1
            }
        }
        
        // Return the most frequent direction
        let mostFrequent = frequencyMap.max { $0.value < $1.value }
        if let key = mostFrequent?.key {
            return GazeDirection(rawValue: key)
        }
        return nil
    }
}