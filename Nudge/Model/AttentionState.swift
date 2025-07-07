import Foundation
import SwiftData

@Model
final class AttentionState: Codable {
    var timestamp: Date
    var isAttentive: Bool
    var confidenceScore: Double
    var eyeOpenness: Double
    var gazeDirection: String
    var headPose: String
    var environmentalFactors: [String: Double]
    var sessionId: UUID
     init(
        timestamp: Date = Date(),
        isAttentive: Bool = false,
        confidenceScore: Double = 0.0,
        eyeOpenness: Double = 0.0,
        gazeDirection: String = "unknown",
        headPose: String = "unknown",
        environmentalFactors: [String: Double] = [:],
        sessionId: UUID = UUID(),
     ) {
        self.timestamp = timestamp
        self.isAttentive = isAttentive
        self.confidenceScore = confidenceScore
        self.eyeOpenness = eyeOpenness
        self.gazeDirection = gazeDirection
        self.headPose = headPose
        self.environmentalFactors = environmentalFactors
        self.sessionId = sessionId
     }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case timestamp, isAttentive, confidenceScore, eyeOpenness
        case gazeDirection, headPose, environmentalFactors, sessionId
        case contextualInfo
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isAttentive = try container.decode(Bool.self, forKey: .isAttentive)
        confidenceScore = try container.decode(Double.self, forKey: .confidenceScore)
        eyeOpenness = try container.decode(Double.self, forKey: .eyeOpenness)
        gazeDirection = try container.decode(String.self, forKey: .gazeDirection)
        headPose = try container.decode(String.self, forKey: .headPose)
        environmentalFactors = try container.decode([String: Double].self, forKey: .environmentalFactors)
        sessionId = try container.decode(UUID.self, forKey: .sessionId)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(isAttentive, forKey: .isAttentive)
        try container.encode(confidenceScore, forKey: .confidenceScore)
        try container.encode(eyeOpenness, forKey: .eyeOpenness)
        try container.encode(gazeDirection, forKey: .gazeDirection)
        try container.encode(headPose, forKey: .headPose)
        try container.encode(environmentalFactors, forKey: .environmentalFactors)
        try container.encode(sessionId, forKey: .sessionId)
     }
}
