import Foundation
import SwiftData

@Model
final class ContextualData: Codable {
    var timestamp: Date
    var activeApplication: String
    var activeWebsite: String?
    var screenBrightness: Double
    var ambientLightLevel: Double
    var thermalState: String
    var batteryLevel: Double
    var isFullscreen: Bool
    var windowCount: Int
    var keyboardActivity: Int
    var mouseMovement: Double
    var sessionId: UUID
    
    init(
        timestamp: Date = Date(),
        activeApplication: String = "",
        activeWebsite: String? = nil,
        screenBrightness: Double = 0.0,
        ambientLightLevel: Double = 0.0,
        thermalState: String = "nominal",
        batteryLevel: Double = 0.0,
        isFullscreen: Bool = false,
        windowCount: Int = 1,
        keyboardActivity: Int = 0,
        mouseMovement: Double = 0.0,
        sessionId: UUID = UUID()
    ) {
        self.timestamp = timestamp
        self.activeApplication = activeApplication
        self.activeWebsite = activeWebsite
        self.screenBrightness = screenBrightness
        self.ambientLightLevel = ambientLightLevel
        self.thermalState = thermalState
        self.batteryLevel = batteryLevel
        self.isFullscreen = isFullscreen
        self.windowCount = windowCount
        self.keyboardActivity = keyboardActivity
        self.mouseMovement = mouseMovement
        self.sessionId = sessionId
    }

    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case timestamp, activeApplication, activeWebsite, screenBrightness, ambientLightLevel, thermalState, batteryLevel, isFullscreen, windowCount, keyboardActivity, mouseMovement, sessionId
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        activeApplication = try container.decode(String.self, forKey: .activeApplication)
        activeWebsite = try container.decode(String.self, forKey: .activeWebsite)
        screenBrightness = try container.decode(Double.self, forKey: .screenBrightness)
        ambientLightLevel = try container.decode(Double.self, forKey: .ambientLightLevel)
        thermalState = try container.decode(String.self, forKey: .thermalState)
        batteryLevel = try container.decode(Double.self, forKey: .batteryLevel)
        isFullscreen = try container.decode(Bool.self, forKey: .isFullscreen)
        windowCount = try container.decode(Int.self, forKey: .windowCount)
        keyboardActivity = try container.decode(Int.self, forKey: .keyboardActivity)
        mouseMovement = try container.decode(Double.self, forKey: .mouseMovement)
        sessionId = try container.decode(UUID.self, forKey: .sessionId)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(activeApplication, forKey: .activeApplication)
        try container.encode(activeWebsite, forKey: .activeWebsite)
        try container.encode(screenBrightness, forKey: .screenBrightness)
        try container.encode(ambientLightLevel, forKey: .ambientLightLevel)
        try container.encode(thermalState, forKey: .thermalState)
        try container.encode(batteryLevel, forKey: .batteryLevel)
        try container.encode(isFullscreen, forKey: .isFullscreen)
        try container.encode(windowCount, forKey: .windowCount)
        try container.encode(keyboardActivity, forKey: .keyboardActivity)
        try container.encode(mouseMovement, forKey: .mouseMovement)
        try container.encode(sessionId, forKey: .sessionId)
    }
}
