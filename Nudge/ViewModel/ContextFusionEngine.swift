import Foundation
import Combine

class ContextFusionEngine: ObservableObject {
    @Published var fusedAttentionScore: Double = 0.0
    @Published var confidenceLevel: Double = 0.0
    @Published var primaryFactors: [AttentionFactor] = []
    @Published var contextualInsights: [String] = []
    
    private let attentionDetector: AttentionDetectionEngine
    private let screenMonitor: ScreenActivityMonitor
    private let localClassifier: LocalAttentionClassifier
    private let apiManager: IntelligentAPIManager
    private let behavioralAnalyzer: BehavioralPatternAnalyzer
    
    private var cancellables = Set<AnyCancellable>()
    private var fusionHistory: [FusionResult] = []
    private let historyLimit = 50
    private var isActive = false
    
    init(attentionDetector: AttentionDetectionEngine,
         screenMonitor: ScreenActivityMonitor,
         localClassifier: LocalAttentionClassifier,
         apiManager: IntelligentAPIManager,
         behavioralAnalyzer: BehavioralPatternAnalyzer) {
        
        self.attentionDetector = attentionDetector
        self.screenMonitor = screenMonitor
        self.localClassifier = localClassifier
        self.apiManager = apiManager
        self.behavioralAnalyzer = behavioralAnalyzer
        
        // Don't setup fusion pipeline automatically - wait for startFusion()
    }
    
    private func setupFusionPipeline() {
        // Combine all data sources and trigger fusion analysis
        Publishers.CombineLatest4(
            attentionDetector.$currentFaceMetrics,
            screenMonitor.$activeApplication,
            localClassifier.$classificationResult,
            behavioralAnalyzer.$currentPatterns
        )
        .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
        .sink { [weak self] faceMetrics, _, classificationResult, patterns in
            // Only perform fusion if engine is active
            guard self?.isActive == true else { return }
            
            Task {
                await self?.performFusion(
                    faceMetrics: faceMetrics,
                    classificationResult: classificationResult,
                    behavioralPatterns: patterns
                )
            }
        }
        .store(in: &cancellables)
    }
    
    @MainActor
    private func performFusion(faceMetrics: FaceMetrics, 
                              classificationResult: AttentionClassification,
                              behavioralPatterns: [BehavioralPattern]) async {
        
        let contextualData = screenMonitor.getCurrentContextualData()
        
        // 1. PRIVACY-FIRST: Always perform local analysis first
        let localAnalysis = analyzeLocalData(
            faceMetrics: faceMetrics,
            contextualData: contextualData,
            classificationResult: classificationResult,
            behavioralPatterns: behavioralPatterns
        )
        
        print("LOCAL ANALYSIS: Confidence \(String(format: "%.2f", localAnalysis.confidence)), Score \(String(format: "%.2f", localAnalysis.attentionScore))")
        
        // 2. Get API enhancement ONLY if local confidence is insufficient
        var apiAnalysis: APIAnalysisResult?
        if localAnalysis.confidence < 0.75 {
            print("LOCAL CONFIDENCE LOW (\(String(format: "%.2f", localAnalysis.confidence))) - Requesting API enhancement")
            apiAnalysis = await apiManager.analyzeAttention(
                faceMetrics: faceMetrics,
                contextualData: contextualData
            )
            
            if let api = apiAnalysis, api.success {
                print("API ANALYSIS: Enhanced with confidence \(String(format: "%.2f", api.confidence))")
            } else {
                print("API ANALYSIS: Failed or skipped - continuing with local analysis only")
            }
        } else {
            print("LOCAL CONFIDENCE SUFFICIENT (\(String(format: "%.2f", localAnalysis.confidence))) - No API call needed")
        }
        
        // 3. Fuse all sources
        let fusionResult = fuseAnalysisResults(
            local: localAnalysis,
            api: apiAnalysis,
            behavioral: behavioralPatterns,
            contextual: contextualData
        )
        
        // 4. Update published properties
        updatePublishedResults(fusionResult)
        
        // 5. Store for learning
        storeFusionResult(fusionResult)
    }
    
    private func analyzeLocalData(faceMetrics: FaceMetrics,
                                 contextualData: ContextualData,
                                 classificationResult: AttentionClassification,
                                 behavioralPatterns: [BehavioralPattern]) -> LocalAnalysisResult {
        
        var attentionScore: Double = 0.0
        var confidence: Double = 0.0
        var factors: [AttentionFactor] = []
        
        // Face-based analysis
        if faceMetrics.faceDetected {
            let faceScore = faceMetrics.attentionScore
            attentionScore += faceScore * 0.4 // Face data weighs 40%
            confidence += Double(faceMetrics.confidence) * 0.4
            
            factors.append(AttentionFactor(
                type: .faceMetrics,
                score: faceScore,
                confidence: Double(faceMetrics.confidence),
                description: "Eye openness: \(faceMetrics.eyeOpenness), Gaze: \(faceMetrics.gazeDirection.rawValue)"
            ))
        }
        
        // Classification-based analysis
        let classificationScore = getClassificationScore(classificationResult)
        attentionScore += classificationScore * 0.3 // ML classification weighs 30%
        confidence += classificationResult.confidence * 0.3
        
        factors.append(AttentionFactor(
            type: .mlClassification,
            score: classificationScore,
            confidence: classificationResult.confidence,
            description: "ML Classification: \(classificationResult.rawValue)"
        ))
        
        // Environmental context analysis
        let environmentScore = analyzeEnvironmentalContext(contextualData)
        attentionScore += environmentScore.score * 0.2 // Environment weighs 20%
        confidence += environmentScore.confidence * 0.2
        
        factors.append(AttentionFactor(
            type: .environmental,
            score: environmentScore.score,
            confidence: environmentScore.confidence,
            description: environmentScore.description
        ))
        
        // Behavioral pattern analysis
        let behavioralScore = analyzeBehavioralPatterns(behavioralPatterns, contextualData)
        attentionScore += behavioralScore.score * 0.1 // Behavioral patterns weigh 10%
        confidence += behavioralScore.confidence * 0.1
        
        factors.append(AttentionFactor(
            type: .behavioral,
            score: behavioralScore.score,
            confidence: behavioralScore.confidence,
            description: behavioralScore.description
        ))
        
        return LocalAnalysisResult(
            attentionScore: min(attentionScore, 1.0),
            confidence: min(confidence, 1.0),
            factors: factors
        )
    }
    
    private func getClassificationScore(_ classification: AttentionClassification) -> Double {
        switch classification {
        case .attentive: return 0.8
        case .inattentive: return 0.2
        case .unknown: return 0.5
        }
    }
    
    private func analyzeEnvironmentalContext(_ contextualData: ContextualData) -> (score: Double, confidence: Double, description: String) {
        var score: Double = 0.5
        var confidence: Double = 0.7
        var factors: [String] = []
        
        // Analyze application context
        if isProductiveApplication(contextualData.activeApplication) {
            score += 0.2
            factors.append("productive app")
        } else if isDistractingApplication(contextualData.activeApplication) {
            score -= 0.3
            factors.append("distracting app")
        }
        
        // Analyze screen setup
        if contextualData.isFullscreen {
            score += 0.1
            factors.append("fullscreen mode")
        }
        
        if contextualData.windowCount > 5 {
            score -= 0.2
            factors.append("many windows")
        }
        
        // Analyze input activity
        if contextualData.keyboardActivity > 20 {
            score += 0.1
            factors.append("active typing")
        }
        
        // Analyze time-based factors
        let hour = Calendar.current.component(.hour, from: contextualData.timestamp)
        if hour >= 9 && hour <= 17 {
            score += 0.1
            factors.append("work hours")
        }
        
        let description = factors.isEmpty ? "Neutral environment" : factors.joined(separator: ", ")
        
        return (min(max(score, 0.0), 1.0), confidence, description)
    }
    
    private func analyzeBehavioralPatterns(_ patterns: [BehavioralPattern], 
                                         _ contextualData: ContextualData) -> (score: Double, confidence: Double, description: String) {
        
        guard !patterns.isEmpty else {
            return (0.5, 0.3, "No behavioral patterns available")
        }
        
        let relevantPatterns = patterns.filter { pattern in
            pattern.applicationContext == contextualData.activeApplication ||
            pattern.timeOfDay == getCurrentTimeOfDay() ||
            pattern.dayOfWeek == getCurrentDayOfWeek()
        }
        
        guard !relevantPatterns.isEmpty else {
            return (0.5, 0.5, "No relevant patterns found")
        }
        
        let averageScore = relevantPatterns.reduce(0.0) { sum, pattern in
            return sum + (pattern.attentionTrend == "improving" ? 0.7 : 
                         pattern.attentionTrend == "declining" ? 0.3 : 0.5)
        } / Double(relevantPatterns.count)
        
        let averageConfidence = relevantPatterns.reduce(0.0) { sum, pattern in
            return sum + pattern.confidence
        } / Double(relevantPatterns.count)
        
        let description = "Based on \(relevantPatterns.count) similar patterns"
        
        return (averageScore, averageConfidence, description)
    }
    
    private func fuseAnalysisResults(local: LocalAnalysisResult,
                                   api: APIAnalysisResult?,
                                   behavioral: [BehavioralPattern],
                                   contextual: ContextualData) -> FusionResult {
        
        var finalScore = local.attentionScore
        var finalConfidence = local.confidence
        var allFactors = local.factors
        var insights: [String] = []
        
        // Incorporate API analysis if available
        if let api = api, api.success {
            let apiWeight = min(api.confidence, 0.3) // API can contribute up to 30%
            finalScore = finalScore * (1.0 - apiWeight) + (api.attentionScore ?? 0.5) * apiWeight
            finalConfidence = max(finalConfidence, api.confidence)
            
            if let factors = api.factors {
                insights.append(contentsOf: factors)
            }
            
            if let recommendations = api.recommendations {
                insights.append(contentsOf: recommendations)
            }
        }
        
        // Add contextual insights
        insights.append(generateContextualInsight(contextual))
        
        return FusionResult(
            timestamp: Date(),
            attentionScore: finalScore,
            confidence: finalConfidence,
            factors: allFactors,
            insights: insights,
            contextualData: contextual
        )
    }
    
    private func generateContextualInsight(_ contextualData: ContextualData) -> String {
        let hour = Calendar.current.component(.hour, from: contextualData.timestamp)
        
        if hour < 9 {
            return "Early morning - natural energy may be building"
        } else if hour < 12 {
            return "Morning peak focus time"
        } else if hour < 14 {
            return "Post-lunch dip possible"
        } else if hour < 17 {
            return "Afternoon focus period"
        } else {
            return "Evening - energy may be declining"
        }
    }
    
    private func updatePublishedResults(_ result: FusionResult) {
        fusedAttentionScore = result.attentionScore
        confidenceLevel = result.confidence
        primaryFactors = result.factors
        contextualInsights = result.insights
    }
    
    private func storeFusionResult(_ result: FusionResult) {
        fusionHistory.append(result)
        
        if fusionHistory.count > historyLimit {
            fusionHistory.removeFirst()
        }
        
        // Update behavioral analyzer with new data
        behavioralAnalyzer.updateWithFusionResult(result)
    }
    
    // MARK: - Helper Methods
    
    private func isProductiveApplication(_ appName: String) -> Bool {
        let productiveApps = ["Xcode", "VS Code", "Terminal", "Word", "Excel", "PowerPoint", "Notion", "Obsidian"]
        return productiveApps.contains { appName.contains($0) }
    }
    
    private func isDistractingApplication(_ appName: String) -> Bool {
        let distractingApps = ["YouTube", "Netflix", "Instagram", "TikTok", "Games", "Messages"]
        return distractingApps.contains { appName.contains($0) }
    }
    
    private func getCurrentTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 6..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<22: return "evening"
        default: return "night"
        }
    }
    
    private func getCurrentDayOfWeek() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date()).lowercased()
    }
}

// MARK: - Supporting Data Structures

struct LocalAnalysisResult {
    let attentionScore: Double
    let confidence: Double
    let factors: [AttentionFactor]
}

struct AttentionFactor {
    let type: AttentionFactorType
    let score: Double
    let confidence: Double
    let description: String
}

enum AttentionFactorType: String, CaseIterable {
    case faceMetrics = "face_metrics"
    case mlClassification = "ml_classification"
    case environmental = "environmental"
    case behavioral = "behavioral"
    case api = "api_analysis"
}

struct FusionResult {
    let timestamp: Date
    let attentionScore: Double
    let confidence: Double
    let factors: [AttentionFactor]
    let insights: [String]
    let contextualData: ContextualData
}

// MARK: - ContextFusionEngine Session Control
extension ContextFusionEngine {
    func startFusion() {
        guard !isActive else { return }
        
        isActive = true
        setupFusionPipeline()
        print("[DEBUG] Context fusion engine started")
    }
    
    func stopFusion() {
        isActive = false
        cancellables.removeAll()
        print("[DEBUG] Context fusion engine stopped")
    }
}
