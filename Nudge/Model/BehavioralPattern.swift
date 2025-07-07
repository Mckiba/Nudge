import Foundation
import SwiftData

@Model
final class BehavioralPattern {
    var id: UUID
    var patternType: String
    var frequency: Int
    var averageDuration: TimeInterval
    var timeOfDay: String
    var dayOfWeek: String
    var applicationContext: String
    var attentionTrend: String
    var confidence: Double
    var lastObserved: Date
    var isActive: Bool
    
    init(
        id: UUID = UUID(),
        patternType: String = "",
        frequency: Int = 0,
        averageDuration: TimeInterval = 0,
        timeOfDay: String = "",
        dayOfWeek: String = "",
        applicationContext: String = "",
        attentionTrend: String = "stable",
        confidence: Double = 0.0,
        lastObserved: Date = Date(),
        isActive: Bool = true
    ) {
        self.id = id
        self.patternType = patternType
        self.frequency = frequency
        self.averageDuration = averageDuration
        self.timeOfDay = timeOfDay
        self.dayOfWeek = dayOfWeek
        self.applicationContext = applicationContext
        self.attentionTrend = attentionTrend
        self.confidence = confidence
        self.lastObserved = lastObserved
        self.isActive = isActive
    }
}