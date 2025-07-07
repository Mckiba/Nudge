import Foundation

class BlinkDetector {
    private var eyeOpennessHistory: [Float] = []
    private var blinkCount: Int = 0
    private var lastBlinkTime: Date = Date()
    private var isEyeClosed: Bool = false
    
    private let historySize = 30 // Keep last 30 measurements
    private let blinkThreshold: Float = 0.25
    private let blinkDurationThreshold: TimeInterval = 0.1
    
    var currentBlinkRate: Double {
        let timeWindow: TimeInterval = 60.0 // 1 minute
        let currentTime = Date()
        let timeSinceLastBlink = currentTime.timeIntervalSince(lastBlinkTime)
        
        if timeSinceLastBlink > timeWindow {
            return 0.0
        }
        
        return Double(blinkCount) / (timeWindow / 60.0) // Blinks per minute
    }
    
    func updateWithEyeOpenness(_ eyeOpenness: Float) {
        eyeOpennessHistory.append(eyeOpenness)
        
        if eyeOpennessHistory.count > historySize {
            eyeOpennessHistory.removeFirst()
        }
        
        detectBlink(eyeOpenness)
    }
    
    private func detectBlink(_ eyeOpenness: Float) {
        let currentTime = Date()
        
        if eyeOpenness < blinkThreshold && !isEyeClosed {
            // Eye just closed
            isEyeClosed = true
        } else if eyeOpenness >= blinkThreshold && isEyeClosed {
            // Eye just opened - this completes a blink
            isEyeClosed = false
            
            let timeSinceLastBlink = currentTime.timeIntervalSince(lastBlinkTime)
            if timeSinceLastBlink > blinkDurationThreshold {
                blinkCount += 1
                lastBlinkTime = currentTime
                
                // Reset blink count if it's been too long
                if timeSinceLastBlink > 60.0 {
                    blinkCount = 1
                }
            }
        }
    }
    
    func getAverageEyeOpenness() -> Float {
        guard !eyeOpennessHistory.isEmpty else { return 0.0 }
        return eyeOpennessHistory.reduce(0, +) / Float(eyeOpennessHistory.count)
    }
    
    func getEyeOpennessVariability() -> Float {
        guard eyeOpennessHistory.count > 1 else { return 0.0 }
        
        let average = getAverageEyeOpenness()
        let squaredDifferences = eyeOpennessHistory.map { pow($0 - average, 2) }
        let variance = squaredDifferences.reduce(0, +) / Float(eyeOpennessHistory.count)
        
        return sqrt(variance)
    }
}