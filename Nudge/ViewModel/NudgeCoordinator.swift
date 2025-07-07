import Foundation
import SwiftData
import Combine
import AVFoundation
import Cocoa

@MainActor
class NudgeCoordinator: ObservableObject {
    // Core engines
    let attentionDetector = AttentionDetectionEngine()
    private let screenMonitor = ScreenActivityMonitor()
    private let localClassifier = LocalAttentionClassifier()
    private let apiManager = IntelligentAPIManager()
    private let performanceOptimizer = PerformanceOptimizer()
    
    // Analysis engines
    private var behavioralAnalyzer: BehavioralPatternAnalyzer!
    private var contextFusion: ContextFusionEngine!
    
    // Published state
    @Published var isActive: Bool = false
    @Published var currentAttentionScore: Double = 0.0
    @Published var confidenceLevel: Double = 0.0
    @Published var activeInsights: [String] = []
    @Published var systemStatus: SystemStatus = .initializing
    
    // SwiftData
    var modelContext: ModelContext?
    
    private var cancellables = Set<AnyCancellable>()
    private var sessionTimer: Timer?
    private let sessionInterval: TimeInterval = 60.0 // Save session data every minute
    private var currentSessionId: UUID = UUID()
    private var currentSessionStates: [AttentionState] = []
    private var currentSessionContextualData: [ContextualData] = []
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        initializeSystem()
    }
    
    private func initializeSystem() {
        // Initialize behavioral analyzer with model context
        behavioralAnalyzer = BehavioralPatternAnalyzer(modelContext: modelContext)
        
        // Initialize context fusion engine
        contextFusion = ContextFusionEngine(
            attentionDetector: attentionDetector,
            screenMonitor: screenMonitor,
            localClassifier: localClassifier,
            apiManager: apiManager,
            behavioralAnalyzer: behavioralAnalyzer
        )
        
        setupDataFlow()
        setupPerformanceOptimization()
        requestPermissions()
        
        systemStatus = .ready
    }
    
    private func setupDataFlow() {
        // Subscribe to context fusion results
        contextFusion.$fusedAttentionScore
            .combineLatest(contextFusion.$confidenceLevel, contextFusion.$contextualInsights)
            .sink { [weak self] score, confidence, insights in
                self?.currentAttentionScore = score
                self?.confidenceLevel = confidence
                self?.activeInsights = insights
            }
            .store(in: &cancellables)
        
        // Subscribe to performance optimizer changes
        performanceOptimizer.$currentProcessingLevel
            .sink { [weak self] level in
                self?.adjustSystemPerformance(for: level)
            }
            .store(in: &cancellables)
        
        // Subscribe to system status changes
        Publishers.CombineLatest3(
            attentionDetector.$isDetecting,
            screenMonitor.$activeApplication,
            apiManager.$isAPIAvailable
        )
        .map { isDetecting, hasActiveApp, apiAvailable in
            if isDetecting && !hasActiveApp.isEmpty {
                return SystemStatus.active
            } else if isDetecting {
                return SystemStatus.monitoring
            } else {
                return SystemStatus.paused
            }
        }
        .assign(to: &$systemStatus)
    }
    
    private func setupPerformanceOptimization() {
        // Listen for performance level changes
        NotificationCenter.default.publisher(for: .performanceLevelChanged)
            .sink { [weak self] notification in
                if let level = notification.userInfo?["level"] as? ProcessingLevel {
                    self?.applyPerformanceSettings(level)
                }
            }
            .store(in: &cancellables)
        
        // Listen for cache clearing requests
        NotificationCenter.default.publisher(for: .shouldClearCaches)
            .sink { [weak self] _ in
                self?.clearSystemCaches()
            }
            .store(in: &cancellables)
    }
    
    private func requestPermissions() {
        // Check current camera permission status
        let cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch cameraAuthStatus {
        case .authorized:
            print("Camera access already granted")
            // Continue with initialization
            
        case .notDetermined:
            // Request camera permissions
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        print("Camera access granted")
                        self.systemStatus = .ready
                    } else {
                        print("Camera access denied")
                        self.systemStatus = .permissionRequired
                    }
                }
            }
            
        case .denied, .restricted:
            print("Camera access denied or restricted")
            systemStatus = .permissionRequired
            
        @unknown default:
            print("Unknown camera authorization status")
            systemStatus = .permissionRequired
        }
        
        // Accessibility permissions are requested by ScreenActivityMonitor
    }
    
    func startMonitoring() {
        // Check camera permissions before starting
        let cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        guard cameraAuthStatus == .authorized else {
            print("Cannot start monitoring - camera permission not granted")
            systemStatus = .permissionRequired
            return
        }
        
        guard systemStatus == .ready || systemStatus == .paused else {
            print("Cannot start monitoring - system not ready")
            return
        }
        
        isActive = true
        
        // Notify API manager that session is active
        apiManager.setSessionState(true)
        
        // Start all monitoring components
        print("Starting camera detection...")
        attentionDetector.startDetection()
        
        print("Starting screen monitoring...")
        screenMonitor.startMonitoring()
        
        print("Starting context fusion...")
        contextFusion.startFusion()
        
        print("Optimizing performance...")
        performanceOptimizer.forceOptimization()
        
        // Start session tracking
        startSessionTracking()
        
        systemStatus = .monitoring
        print("Nudge monitoring started successfully")
    }
    
    func stopMonitoring() {
        isActive = false
        
        // Notify API manager that session is inactive
        apiManager.setSessionState(false)
        
        // Stop all monitoring components
        attentionDetector.stopDetection()
        screenMonitor.stopMonitoring()
        contextFusion.stopFusion()
        
        // Stop session tracking
        stopSessionTracking()
        
        systemStatus = .paused
        print("Nudge monitoring stopped")
    }
    
    private func startSessionTracking() {
        // Start new session
        currentSessionId = UUID()
        currentSessionStates = []
        currentSessionContextualData = []
        
        sessionTimer = Timer.scheduledTimer(withTimeInterval: sessionInterval, repeats: true) { [weak self] _ in
            self?.saveCurrentSession()
        }
    }
    
    private func stopSessionTracking() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        saveCurrentSession() // Save final session data
        exportSessionToJSON() // Export session data to JSON
    }
    
    private func saveCurrentSession() {
        guard let modelContext = modelContext else { return }
        
        let contextualData = screenMonitor.getCurrentContextualData()
        let currentFaceMetrics = attentionDetector.currentFaceMetrics
        
        // Set contextual data sessionId to match current session
        contextualData.sessionId = currentSessionId
        
        // Save attention state
        let attentionState = AttentionState(
            timestamp: Date(),
            isAttentive: currentAttentionScore > 0.6,
            confidenceScore: confidenceLevel,
            eyeOpenness: Double(currentFaceMetrics.eyeOpenness),
            gazeDirection: currentFaceMetrics.gazeDirection.rawValue,
            headPose: currentFaceMetrics.headPose.rawValue,
            environmentalFactors: [
                "screenBrightness": contextualData.screenBrightness,
                "batteryLevel": contextualData.batteryLevel,
                "thermalState": thermalStateToNumber(contextualData.thermalState)
            ],
            sessionId: currentSessionId
        )
        
        //save contextualData

        // Add to current session states for JSON export
        currentSessionStates.append(attentionState)
        currentSessionContextualData.append(contextualData)
        
        modelContext.insert(attentionState)
        modelContext.insert(contextualData)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save session data: \(error)")
        }
    }
    
    private func thermalStateToNumber(_ thermalState: String) -> Double {
        switch thermalState {
        case "nominal": return 0.0
        case "fair": return 0.3
        case "serious": return 0.7
        case "critical": return 1.0
        default: return 0.5
        }
    }
    
    private func adjustSystemPerformance(for level: ProcessingLevel) {
        // Adjust attention detection based on performance level
        let interval = performanceOptimizer.getOptimalProcessingInterval()
        
        // This would be implemented in AttentionDetectionEngine
        // attentionDetector.setProcessingInterval(interval)
        
        print("Adjusted system performance for level: \(level.rawValue)")
    }
    
    private func applyPerformanceSettings(_ level: ProcessingLevel) {
        switch level {
        case .minimal:
            // Reduce all processing to minimum
            break
        case .reduced:
            // Moderate reduction in processing
            break
        case .normal:
            // Standard processing
            break
        case .optimal:
            // Full processing capabilities
            break
        }
    }
    
    private func clearSystemCaches() {
        // Clear any local caches
        localClassifier.modelConfidence = 0.0
        
        // Reset temporary data
        activeInsights = []
        
        print("System caches cleared")
    }
    
    // MARK: - Public Interface
    
    func getAttentionMetrics() -> AttentionMetrics {
        let faceMetrics = attentionDetector.currentFaceMetrics
        let contextualData = screenMonitor.getCurrentContextualData()
        
        return AttentionMetrics(
            attentionScore: currentAttentionScore,
            confidence: confidenceLevel,
            isAttentive: currentAttentionScore > 0.6,
            faceDetected: faceMetrics.faceDetected,
            eyeOpenness: Double(faceMetrics.eyeOpenness),
            gazeDirection: faceMetrics.gazeDirection.rawValue,
            activeApplication: contextualData.activeApplication,
            insights: activeInsights,
            timestamp: Date()
        )
    }
    
    func getBehavioralInsights() -> [String] {
        return behavioralAnalyzer.recentInsights
    }
    
    func getSystemHealth() -> SystemHealth {
        let performanceMetrics = performanceOptimizer.getPerformanceMetrics()
        
        return SystemHealth(
            isHealthy: systemStatus == .active || systemStatus == .monitoring,
            thermalState: performanceMetrics.thermalState,
            memoryPressure: performanceMetrics.memoryPressure,
            batteryLevel: performanceMetrics.batteryLevel,
            processingLevel: performanceMetrics.processingLevel,
            apiCallsRemaining: 100 - apiManager.dailyAPICallCount
        )
    }
    
    func exportData(for dateRange: DateRange) async -> NudgeDataExport {
        guard let modelContext = modelContext else {
            return NudgeDataExport(dateRange: dateRange, attentionStates: [], patterns: [])
        }
        
        // Fetch attention states for date range
        let attentionDescriptor = FetchDescriptor<AttentionState>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        let patternDescriptor = FetchDescriptor<BehavioralPattern>(
            sortBy: [SortDescriptor(\.lastObserved, order: .reverse)]
        )
        
        do {
            let allAttentionStates = try modelContext.fetch(attentionDescriptor)
            let allPatterns = try modelContext.fetch(patternDescriptor)
            
            // Filter by date range manually for now
            let attentionStates = allAttentionStates.filter { state in
                state.timestamp >= dateRange.start && state.timestamp <= dateRange.end
            }
            let patterns = allPatterns.filter { pattern in
                pattern.lastObserved >= dateRange.start && pattern.lastObserved <= dateRange.end
            }
            
            return NudgeDataExport(
                dateRange: dateRange,
                attentionStates: attentionStates,
                patterns: patterns
            )
        } catch {
            print("Failed to export data: \(error)")
            return NudgeDataExport(dateRange: dateRange, attentionStates: [], patterns: [])
        }
    }
    
   //MARK: - Request Folder Access
    
    func requestDownloadsAccess() -> URL? {
        let openPanel = NSOpenPanel()
        openPanel.title = "Grant Access to Downloads Folder"
        openPanel.message = "Please select your Downloads folder to grant access for session export"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        
        // Pre-navigate to Downloads folder
        openPanel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        
        if openPanel.runModal() == .OK {
            return openPanel.url
        }
        return nil
    }
    
    // MARK: - JSON Export
    
    private func exportSessionToJSON() {
        guard !currentSessionStates.isEmpty || !currentSessionContextualData.isEmpty else {
            print("No session data to export")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let sessionExport = SessionExport(
                sessionId: currentSessionId,
                sessionStart: currentSessionStates.first?.timestamp ?? currentSessionContextualData.first?.timestamp ?? Date(),
                sessionEnd: currentSessionStates.last?.timestamp ?? currentSessionContextualData.last?.timestamp ?? Date(),
                totalDataPoints: currentSessionStates.count,
                attentionStates: currentSessionStates,
                contextualData: currentSessionContextualData
            )
            
            let jsonData = try encoder.encode(sessionExport)
            
            // Create filename with timestamp
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let timestamp = formatter.string(from: Date())
            let filename = "nudge_session_\(timestamp).json"
            
            // Save to current working directory (app's local directory)
            let currentDirectory = FileManager.default.currentDirectoryPath
            let fileURL = URL(fileURLWithPath: currentDirectory).appendingPathComponent(filename)
            
            try jsonData.write(to: fileURL)
            print("Session exported to local directory: \(fileURL.path)")
            
            // Print session summary
            print("Session summary:")
            print("  - Session ID: \(currentSessionId)")
            print("  - Attention data points: \(currentSessionStates.count)")
            print("  - Contextual data points: \(currentSessionContextualData.count)")
            print("  - Duration: \(sessionExport.sessionEnd.timeIntervalSince(sessionExport.sessionStart)) seconds")
            print("  - File location: \(fileURL.path)")
            
        } catch {
            print("Failed to export session to JSON: \(error)")
        }
    }
}

// MARK: - Supporting Types

enum SystemStatus: String, CaseIterable {
    case initializing = "initializing"
    case ready = "ready"
    case monitoring = "monitoring"
    case active = "active"
    case paused = "paused"
    case permissionRequired = "permission_required"
    case error = "error"
    
    var description: String {
        switch self {
        case .initializing: return "Starting up..."
        case .ready: return "Ready to start"
        case .monitoring: return "Monitoring attention"
        case .active: return "Actively tracking"
        case .paused: return "Paused"
        case .permissionRequired: return "Permissions needed"
        case .error: return "System error"
        }
    }
}

struct AttentionMetrics {
    let attentionScore: Double
    let confidence: Double
    let isAttentive: Bool
    let faceDetected: Bool
    let eyeOpenness: Double
    let gazeDirection: String
    let activeApplication: String
    let insights: [String]
    let timestamp: Date
}

struct SystemHealth {
    let isHealthy: Bool
    let thermalState: ProcessInfo.ThermalState
    let memoryPressure: MemoryPressure
    let batteryLevel: Double
    let processingLevel: ProcessingLevel
    let apiCallsRemaining: Int
}

struct DateRange {
    let start: Date
    let end: Date
}

struct NudgeDataExport {
    let dateRange: DateRange
    let attentionStates: [AttentionState]
    let patterns: [BehavioralPattern]
}

struct SessionExport: Codable {
    let sessionId: UUID
    let sessionStart: Date
    let sessionEnd: Date
    let totalDataPoints: Int
    let attentionStates: [AttentionState]
    let contextualData: [ContextualData]
}
