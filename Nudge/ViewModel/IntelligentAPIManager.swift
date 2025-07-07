import Foundation
import Combine

class IntelligentAPIManager: ObservableObject {
    @Published var dailyAPICallCount: Int = 0
    @Published var isAPIAvailable: Bool = true
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var isSessionActive: Bool = false
    
    private let maxDailyAPICalls = 100
    private let confidenceThreshold: Double = 0.7
    private let minAPIRequestInterval: TimeInterval = 60.0 // Minimum 10 seconds between requests
    
    private var apiKey: String?
    private var urlSession: URLSession
    private var lastResetDate: Date
    private var lastAPIRequestTime: Date = Date.distantPast
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.urlSession = URLSession.shared
        self.lastResetDate = Date()
        
        loadAPIKey()
        setupThermalStateMonitoring()
        resetDailyCountIfNeeded()
    }
    
    private func loadAPIKey() {
        
     
 
        // Load API key from environment variable
        apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        
        if let key = apiKey {
            let keyLength = key.count
            let keyPrefix = key.prefix(8)
            let keyIsValid = keyLength >= 40 && key.hasPrefix("sk-")
         } else {
            print("[DEBUG] OPENAI_API_KEY environment variable not found")
             print("[DEBUG] Process info available: \(ProcessInfo.processInfo.processName)")
        }
        
        print("[DEBUG] API key loading complete. Key available: \(apiKey != nil)")
    }
    
    private func setupThermalStateMonitoring() {
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .sink { [weak self] _ in
                self?.thermalState = ProcessInfo.processInfo.thermalState
                self?.updateAPIAvailability()
            }
            .store(in: &cancellables)
    }
    
    private func resetDailyCountIfNeeded() {
        let calendar = Calendar.current
        if !calendar.isDate(lastResetDate, inSameDayAs: Date()) {
            dailyAPICallCount = 0
            lastResetDate = Date()
            updateAPIAvailability()
        }
    }
    
    private func updateAPIAvailability() {
        let thermalStateIsAcceptable = thermalState == .nominal || thermalState == .fair
        let hasAPIKey = apiKey != nil
        let withinDailyLimit = dailyAPICallCount < maxDailyAPICalls
        
         
        
        isAPIAvailable = withinDailyLimit && thermalStateIsAcceptable && hasAPIKey
        
     }
    
    func shouldUseAPI(localConfidence: Double, context: AnalysisContext) -> Bool {
        resetDailyCountIfNeeded()
       
        
        // Check if session is active first
        guard isSessionActive else {
            print("[DEBUG] No active session - API calls disabled")
            return false
        }
        
        guard isAPIAvailable else { 
            print("[DEBUG] API not available - returning false")
            return false 
        }
        
        // Check rate limiting - minimum interval between requests
        let timeSinceLastRequest = Date().timeIntervalSince(lastAPIRequestTime)
        if timeSinceLastRequest < minAPIRequestInterval {
            print("[DEBUG] Rate limited - last request \(String(format: "%.1f", timeSinceLastRequest))s ago (min: \(minAPIRequestInterval)s)")
            return false
        }
        
        // Use API when local confidence is low
        if localConfidence < confidenceThreshold {
            print("[DEBUG] Low confidence (\(localConfidence) < \(confidenceThreshold)) - using API")
            return true
        }
        
        // Use API for complex scenarios even with decent local confidence
        if context.isComplexScenario && localConfidence < 0.85 {
            print("[DEBUG] Complex scenario with moderate confidence - using API")
            return true
        }
        
        // Use API for learning new patterns occasionally
        if context.isNovelPattern && dailyAPICallCount < Int(Double(maxDailyAPICalls) * 0.2) {
            print("[DEBUG] Novel pattern within learning budget - using API")
            return true
        }
        
        print("[DEBUG] Conditions not met - not using API")
        return false
    }
    
    func analyzeAttention(faceMetrics: FaceMetrics, contextualData: ContextualData) async -> APIAnalysisResult {
        print("[DEBUG] Starting attention analysis...")
        
        let analysisContext = AnalysisContext(faceMetrics: faceMetrics, contextualData: contextualData)
        let shouldUse = shouldUseAPI(localConfidence: Double(faceMetrics.confidence), context: analysisContext)
        
        guard shouldUse else {
            print("[DEBUG] Should not use API - returning early")
            return APIAnalysisResult(success: false, confidence: 0.0, analysis: "API usage not recommended")
        }
        
        guard let apiKey = apiKey else {
            print("[DEBUG] No API key available - cannot proceed")
            return APIAnalysisResult(success: false, confidence: 0.0, analysis: "API key not available")
        }
        
        print("[DEBUG] Proceeding with API analysis...")
        
        // Update last request time to enforce rate limiting
        lastAPIRequestTime = Date()
        
        do {
            let result = try await performAPIAnalysis(faceMetrics: faceMetrics, 
                                                contextualData: contextualData, 
                                                apiKey: apiKey)
            
            print("[DEBUG] API analysis completed successfully: \(result.success)")
            
            if result.success {
                dailyAPICallCount += 1
                print("[DEBUG] Incremented daily API call count to \(dailyAPICallCount)")
                updateAPIAvailability()
            }
            
            return result
        } catch {
            print("[DEBUG] API analysis failed with error: \(error)")
            if let urlError = error as? URLError {
                print("[DEBUG] URL Error details:")
                print("[DEBUG]   Code: \(urlError.code.rawValue)")
                print("[DEBUG]   Description: \(urlError.localizedDescription)")
                print("[DEBUG]   Failing URL: \(urlError.failingURL?.absoluteString ?? "none")")
            }
            return APIAnalysisResult(success: false, confidence: 0.0, analysis: "API call failed: \(error.localizedDescription)")
        }
    }
    
    private func performAPIAnalysis(faceMetrics: FaceMetrics, 
                                  contextualData: ContextualData, 
                                  apiKey: String) async throws -> APIAnalysisResult  {
        
        print("[DEBUG] Constructing API request...")
        
        let prompt = constructAnalysisPrompt(faceMetrics: faceMetrics, contextualData: contextualData)
        
        let requestBody = OpenAIRequest(
            model: "gpt-4o-mini",
            messages: [
                OpenAIMessage(role: "system", content: systemPrompt),
                OpenAIMessage(role: "user", content: prompt)
            ],
            maxTokens: 200,
            temperature: 0.3
        )
        
        // Note: Using chat completions endpoint instead of completions
        let apiURL = "https://api.openai.com/v1/chat/completions"
        print("[DEBUG] API URL: \(apiURL)")
        
        guard let url = URL(string: apiURL) else {
            print("[DEBUG] Invalid API URL")
            throw APIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("[DEBUG] Request headers set")
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
            print("[DEBUG] Request body encoded successfully")
            
            print("[DEBUG] Making API request...")
            let (data, response) = try await urlSession.data(for: request)
            
            print("[DEBUG] Received response")
            
            if let httpResponse = response as? HTTPURLResponse {
                print("[DEBUG] HTTP Status Code: \(httpResponse.statusCode)")
                print("[DEBUG] Response headers: \(httpResponse.allHeaderFields)")
                
                if httpResponse.statusCode != 200 {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("[DEBUG] Error response body: \(responseString)")
                    }
                    throw APIError.invalidResponse
                }
            }
            
            print("[DEBUG] Attempting to decode response...")
            let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            print("[DEBUG] Response decoded successfully")
            
            return parseAPIResponse(openAIResponse)
            
        } catch let encodingError as EncodingError {
            print("[DEBUG] Encoding error: \(encodingError)")
            throw encodingError
        } catch let decodingError as DecodingError {
            print("[DEBUG] Decoding error: \(decodingError)")
//            if let responseString = String(data: data, encoding: .utf8) {
//                print("[DEBUG] Raw response: \(responseString)")
//            }
            throw decodingError
        } catch {
            print("[DEBUG] General error: \(error)")
            throw error
        }
    }
    
    private func constructAnalysisPrompt(faceMetrics: FaceMetrics, contextualData: ContextualData) -> String {
        return """
        Analyze this attention state data:
        
        Face Detection:
        - Face detected: \(faceMetrics.faceDetected)
        - Eye openness: \(faceMetrics.eyeOpenness)
        - Gaze direction: \(faceMetrics.gazeDirection.rawValue)
        - Head pose: \(faceMetrics.headPose.rawValue)
        - Blink rate: \(faceMetrics.blinkRate) per minute
        - Detection confidence: \(faceMetrics.confidence)
        
        Environmental Context:
        - Active application: \(contextualData.activeApplication)
        - Screen brightness: \(contextualData.screenBrightness)
        - Time of day: \(DateFormatter.timeFormatter.string(from: contextualData.timestamp))
        - Thermal state: \(contextualData.thermalState)
        
        Provide a JSON response with:
        1. attention_score (0-1): Overall attention level
        2. confidence (0-1): Your confidence in this assessment
        3. factors: Key factors influencing attention
        4. recommendations: Brief suggestions for improvement
        """
    }
    
    private func parseAPIResponse(_ response: OpenAIResponse) -> APIAnalysisResult {
        guard let content = response.choices.first?.message.content else {
            return APIAnalysisResult(success: false, confidence: 0.0, analysis: "No content in response")
        }
        
        // Try to parse JSON response
        if let data = content.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            let attentionScore = json["attention_score"] as? Double ?? 0.0
            let confidence = json["confidence"] as? Double ?? 0.0
            let factors = json["factors"] as? [String] ?? []
            let recommendations = json["recommendations"] as? [String] ?? []
            
            return APIAnalysisResult(
                success: true,
                confidence: confidence,
                analysis: content,
                attentionScore: attentionScore,
                factors: factors,
                recommendations: recommendations
            )
        }
        
        // Fallback to text analysis if JSON parsing fails
        return APIAnalysisResult(success: true, confidence: 0.7, analysis: content)
    }
    
    private var systemPrompt: String {
        """
        You are an expert attention and focus analyst. Your role is to assess human attention states based on facial metrics and environmental context. 
        
        Provide accurate, helpful analysis in JSON format. Focus on:
        - Eye openness and blink patterns
        - Gaze direction and stability  
        - Head pose and positioning
        - Environmental factors affecting focus
        - Practical recommendations for improvement
        
        Be concise and actionable in your analysis.
        """
    }
    
    func setSessionState(_ active: Bool) {
        isSessionActive = active
        print("[DEBUG] Session state updated: \(active ? "ACTIVE" : "INACTIVE")")
        
        // Reset API request timer when session starts to allow immediate API call if needed
        if active {
            lastAPIRequestTime = Date.distantPast
        }
    }
}

struct AnalysisContext {
    let isComplexScenario: Bool
    let isNovelPattern: Bool
    let environmentalFactors: [String]
    
    init(faceMetrics: FaceMetrics, contextualData: ContextualData) {
        // Determine if this is a complex scenario requiring API analysis
        self.isComplexScenario = faceMetrics.confidence < 0.6 || 
                                contextualData.windowCount > 5 ||
                                contextualData.thermalState != "nominal"
        
        // Determine if this represents a novel pattern
        self.isNovelPattern = faceMetrics.gazeDirection == .unknown ||
                             faceMetrics.headPose == .unknown ||
                             contextualData.activeApplication.isEmpty
        
        self.environmentalFactors = []
    }
}

struct APIAnalysisResult {
    let success: Bool
    let confidence: Double
    let analysis: String
    let attentionScore: Double?
    let factors: [String]?
    let recommendations: [String]?
    
    init(success: Bool, confidence: Double, analysis: String, 
         attentionScore: Double? = nil, factors: [String]? = nil, recommendations: [String]? = nil) {
        self.success = success
        self.confidence = confidence
        self.analysis = analysis
        self.attentionScore = attentionScore
        self.factors = factors
        self.recommendations = recommendations
    }
}

// MARK: - OpenAI API Models

private struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let maxTokens: Int
    let temperature: Double
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

private struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

private struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
}

private struct OpenAIChoice: Codable {
    let message: OpenAIMessage
}

private enum APIError: Error {
    case invalidResponse
    case noContent
}

private extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}
