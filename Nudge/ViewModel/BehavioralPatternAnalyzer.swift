import Foundation
import Combine
import SwiftData

class BehavioralPatternAnalyzer: ObservableObject {
    @Published var currentPatterns: [BehavioralPattern] = []
    @Published var recentInsights: [String] = []
    
    private var modelContext: ModelContext?
    private var fusionHistory: [FusionResult] = []
    private var patternDetectionTimer: Timer?
    
    private let analysisInterval: TimeInterval = 300 // 5 minutes
    private let minDataPointsForPattern = 10
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        startPatternDetection()
        loadExistingPatterns()
    }
    
    deinit {
        patternDetectionTimer?.invalidate()
    }
    
    private func startPatternDetection() {
        patternDetectionTimer = Timer.scheduledTimer(withTimeInterval: analysisInterval, repeats: true) { [weak self] _ in
            self?.analyzePatterns()
        }
    }
    
    private func loadExistingPatterns() {
        guard let modelContext = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<BehavioralPattern>(
                predicate: #Predicate { $0.isActive == true },
                sortBy: [SortDescriptor(\.lastObserved, order: .reverse)]
            )
            currentPatterns = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to load existing patterns: \(error)")
        }
    }
    
    func updateWithFusionResult(_ result: FusionResult) {
        fusionHistory.append(result)
        
        // Keep only recent history for pattern detection
        let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60) // Last 24 hours
        fusionHistory = fusionHistory.filter { $0.timestamp > cutoffDate }
        
        // Trigger immediate analysis if we have enough new data
        if fusionHistory.count % 20 == 0 {
            analyzePatterns()
        }
    }
    
    private func analyzePatterns() {
        guard fusionHistory.count >= minDataPointsForPattern else { return }
        
        let newPatterns: [BehavioralPattern] = []
        
        // Analyze different types of patterns
        let timeBasedPatterns = detectTimeBasedPatterns()
        let applicationBasedPatterns = detectApplicationBasedPatterns()
        let environmentalPatterns = detectEnvironmentalPatterns()
        let attentionTrendPatterns = detectAttentionTrendPatterns()
        
        let allNewPatterns = timeBasedPatterns + applicationBasedPatterns + 
                            environmentalPatterns + attentionTrendPatterns
        
        // Update current patterns
        updateCurrentPatterns(with: allNewPatterns)
        
        // Generate insights
        generateInsights(from: allNewPatterns)
    }
    
    private func detectTimeBasedPatterns() -> [BehavioralPattern] {
        var patterns: [BehavioralPattern] = []
        
        // Group data by hour of day
        let hourlyGroups = Dictionary(grouping: fusionHistory) { result in
            Calendar.current.component(.hour, from: result.timestamp)
        }
        
        for (hour, results) in hourlyGroups {
            guard results.count >= 5 else { continue }
            
            let averageAttention = results.reduce(0.0) { $0 + $1.attentionScore } / Double(results.count)
            let averageDuration = calculateAverageDuration(results)
            let frequency = results.count
            
            if averageAttention > 0.7 || averageAttention < 0.3 {
                let patternType = averageAttention > 0.7 ? "high_attention_hour" : "low_attention_hour"
                let trend = determineTrend(results.map { $0.attentionScore })
                
                let pattern = BehavioralPattern(
                    patternType: patternType,
                    frequency: frequency,
                    averageDuration: averageDuration,
                    timeOfDay: "\(hour):00",
                    dayOfWeek: "",
                    applicationContext: "",
                    attentionTrend: trend,
                    confidence: calculatePatternConfidence(results),
                    lastObserved: results.last?.timestamp ?? Date()
                )
                
                patterns.append(pattern)
            }
        }
        
        // Group data by day of week
        let weeklyGroups = Dictionary(grouping: fusionHistory) { result in
            Calendar.current.component(.weekday, from: result.timestamp)
        }
        
        for (weekday, results) in weeklyGroups {
            guard results.count >= 5 else { continue }
            
            let averageAttention = results.reduce(0.0) { $0 + $1.attentionScore } / Double(results.count)
            let dayName = getDayName(from: weekday)
            
            if averageAttention > 0.7 || averageAttention < 0.3 {
                let patternType = averageAttention > 0.7 ? "productive_day" : "unfocused_day"
                let trend = determineTrend(results.map { $0.attentionScore })
                
                let pattern = BehavioralPattern(
                    patternType: patternType,
                    frequency: results.count,
                    averageDuration: calculateAverageDuration(results),
                    timeOfDay: "",
                    dayOfWeek: dayName,
                    applicationContext: "",
                    attentionTrend: trend,
                    confidence: calculatePatternConfidence(results),
                    lastObserved: results.last?.timestamp ?? Date()
                )
                
                patterns.append(pattern)
            }
        }
        
        return patterns
    }
    
    private func detectApplicationBasedPatterns() -> [BehavioralPattern] {
        var patterns: [BehavioralPattern] = []
        
        let appGroups = Dictionary(grouping: fusionHistory) { result in
            result.contextualData.activeApplication
        }
        
        for (app, results) in appGroups {
            guard results.count >= 5 && !app.isEmpty else { continue }
            
            let averageAttention = results.reduce(0.0) { $0 + $1.attentionScore } / Double(results.count)
            let averageDuration = calculateAverageDuration(results)
            let trend = determineTrend(results.map { $0.attentionScore })
            
            let patternType: String
            if averageAttention > 0.7 {
                patternType = "high_focus_app"
            } else if averageAttention < 0.3 {
                patternType = "distraction_app"
            } else {
                patternType = "neutral_app"
            }
            
            let pattern = BehavioralPattern(
                patternType: patternType,
                frequency: results.count,
                averageDuration: averageDuration,
                timeOfDay: "",
                dayOfWeek: "",
                applicationContext: app,
                attentionTrend: trend,
                confidence: calculatePatternConfidence(results),
                lastObserved: results.last?.timestamp ?? Date()
            )
            
            patterns.append(pattern)
        }
        
        return patterns
    }
    
    private func detectEnvironmentalPatterns() -> [BehavioralPattern] {
        var patterns: [BehavioralPattern] = []
        
        // Analyze fullscreen vs windowed patterns
        let fullscreenResults = fusionHistory.filter { $0.contextualData.isFullscreen }
        let windowedResults = fusionHistory.filter { !$0.contextualData.isFullscreen }
        
        if fullscreenResults.count >= 5 {
            let averageAttention = fullscreenResults.reduce(0.0) { $0 + $1.attentionScore } / Double(fullscreenResults.count)
            let trend = determineTrend(fullscreenResults.map { $0.attentionScore })
            
            let pattern = BehavioralPattern(
                patternType: "fullscreen_mode",
                frequency: fullscreenResults.count,
                averageDuration: calculateAverageDuration(fullscreenResults),
                timeOfDay: "",
                dayOfWeek: "",
                applicationContext: "",
                attentionTrend: trend,
                confidence: calculatePatternConfidence(fullscreenResults),
                lastObserved: fullscreenResults.last?.timestamp ?? Date()
            )
            
            patterns.append(pattern)
        }
        
        // Analyze multi-window patterns
        let multiWindowResults = fusionHistory.filter { $0.contextualData.windowCount > 3 }
        
        if multiWindowResults.count >= 5 {
            let averageAttention = multiWindowResults.reduce(0.0) { $0 + $1.attentionScore } / Double(multiWindowResults.count)
            let trend = determineTrend(multiWindowResults.map { $0.attentionScore })
            
            let pattern = BehavioralPattern(
                patternType: "multi_window_environment",
                frequency: multiWindowResults.count,
                averageDuration: calculateAverageDuration(multiWindowResults),
                timeOfDay: "",
                dayOfWeek: "",
                applicationContext: "",
                attentionTrend: trend,
                confidence: calculatePatternConfidence(multiWindowResults),
                lastObserved: multiWindowResults.last?.timestamp ?? Date()
            )
            
            patterns.append(pattern)
        }
        
        return patterns
    }
    
    private func detectAttentionTrendPatterns() -> [BehavioralPattern] {
        var patterns: [BehavioralPattern] = []
        
        guard fusionHistory.count >= 20 else { return patterns }
        
        // Analyze attention trends over time windows
        let recentResults = Array(fusionHistory.suffix(20))
        let olderResults = Array(fusionHistory.prefix(fusionHistory.count - 20).suffix(20))
        
        let recentAverage = recentResults.reduce(0.0) { $0 + $1.attentionScore } / Double(recentResults.count)
        let olderAverage = olderResults.reduce(0.0) { $0 + $1.attentionScore } / Double(olderResults.count)
        
        let trendChange = recentAverage - olderAverage
        
        if abs(trendChange) > 0.1 {
            let patternType = trendChange > 0 ? "improving_attention" : "declining_attention"
            let trend = trendChange > 0 ? "improving" : "declining"
            
            let pattern = BehavioralPattern(
                patternType: patternType,
                frequency: recentResults.count,
                averageDuration: calculateAverageDuration(recentResults),
                timeOfDay: "",
                dayOfWeek: "",
                applicationContext: "",
                attentionTrend: trend,
                confidence: 0.8,
                lastObserved: recentResults.last?.timestamp ?? Date()
            )
            
            patterns.append(pattern)
        }
        
        return patterns
    }
    
    private func calculateAverageDuration(_ results: [FusionResult]) -> TimeInterval {
        guard results.count > 1 else { return 0 }
        
        let sortedResults = results.sorted { $0.timestamp < $1.timestamp }
        var totalDuration: TimeInterval = 0
        
        for i in 1..<sortedResults.count {
            let duration = sortedResults[i].timestamp.timeIntervalSince(sortedResults[i-1].timestamp)
            if duration < 600 { // Ignore gaps longer than 10 minutes
                totalDuration += duration
            }
        }
        
        return totalDuration / Double(sortedResults.count - 1)
    }
    
    private func determineTrend(_ scores: [Double]) -> String {
        guard scores.count >= 3 else { return "stable" }
        
        let firstHalf = Array(scores.prefix(scores.count / 2))
        let secondHalf = Array(scores.suffix(scores.count / 2))
        
        let firstAverage = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAverage = secondHalf.reduce(0, +) / Double(secondHalf.count)
        
        let difference = secondAverage - firstAverage
        
        if difference > 0.1 {
            return "improving"
        } else if difference < -0.1 {
            return "declining"
        } else {
            return "stable"
        }
    }
    
    private func calculatePatternConfidence(_ results: [FusionResult]) -> Double {
        let averageConfidence = results.reduce(0.0) { $0 + $1.confidence } / Double(results.count)
        let frequencyBonus = min(Double(results.count) / 20.0, 0.2) // Up to 20% bonus for frequency
        
        return min(averageConfidence + frequencyBonus, 1.0)
    }
    
    private func getDayName(from weekday: Int) -> String {
        let days = ["", "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        return days[weekday]
    }
    
    private func updateCurrentPatterns(with newPatterns: [BehavioralPattern]) {
        // Merge new patterns with existing ones
        var updatedPatterns = currentPatterns
        
        for newPattern in newPatterns {
            if let existingIndex = updatedPatterns.firstIndex(where: { existing in
                existing.patternType == newPattern.patternType &&
                existing.applicationContext == newPattern.applicationContext &&
                existing.timeOfDay == newPattern.timeOfDay &&
                existing.dayOfWeek == newPattern.dayOfWeek
            }) {
                // Update existing pattern
                updatedPatterns[existingIndex] = newPattern
            } else {
                // Add new pattern
                updatedPatterns.append(newPattern)
            }
        }
        
        // Remove patterns that haven't been observed recently
        let cutoffDate = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days
        updatedPatterns = updatedPatterns.filter { $0.lastObserved > cutoffDate }
        
        currentPatterns = updatedPatterns
        
        // Save to persistent storage
        savePatterns(updatedPatterns)
    }
    
    private func savePatterns(_ patterns: [BehavioralPattern]) {
        guard let modelContext = modelContext else { return }
        
        // Clear existing patterns and save new ones
        do {
            let existingPatterns = try modelContext.fetch(FetchDescriptor<BehavioralPattern>())
            for pattern in existingPatterns {
                modelContext.delete(pattern)
            }
            
            for pattern in patterns {
                modelContext.insert(pattern)
            }
            
            try modelContext.save()
        } catch {
            print("Failed to save patterns: \(error)")
        }
    }
    
    private func generateInsights(from patterns: [BehavioralPattern]) {
        var insights: [String] = []
        
        // Generate insights based on patterns
        let highFocusApps = patterns.filter { $0.patternType == "high_focus_app" }
        let distractionApps = patterns.filter { $0.patternType == "distraction_app" }
        let productiveHours = patterns.filter { $0.patternType == "high_attention_hour" }
        let improvingTrends = patterns.filter { $0.attentionTrend == "improving" }
        
        if !highFocusApps.isEmpty {
            let appNames = highFocusApps.map { $0.applicationContext }.joined(separator: ", ")
            insights.append("High focus detected in: \(appNames)")
        }
        
        if !distractionApps.isEmpty {
            let appNames = distractionApps.map { $0.applicationContext }.joined(separator: ", ")
            insights.append("Attention drops noticed in: \(appNames)")
        }
        
        if !productiveHours.isEmpty {
            let hours = productiveHours.map { $0.timeOfDay }.joined(separator: ", ")
            insights.append("Peak focus hours: \(hours)")
        }
        
        if !improvingTrends.isEmpty {
            insights.append("Positive attention trends detected in \(improvingTrends.count) areas")
        }
        
        recentInsights = insights
    }
}
