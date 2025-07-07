import Foundation
import Combine
import os.log
import IOKit.ps

class PerformanceOptimizer: ObservableObject {
    @Published var currentProcessingLevel: ProcessingLevel = .normal
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var memoryPressure: MemoryPressure = .normal
    @Published var batteryLevel: Double = 1.0
    @Published var isOptimizing: Bool = false
    
    private var performanceTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private let logger = Logger(subsystem: "com.nudge.performance", category: "optimizer")
    
    // Performance thresholds
    private let batteryThreshold: Double = 0.2
    private let memoryPressureThreshold: MemoryPressure = .warning
    
    // Frame processing optimization
    @Published var frameProcessingInterval: Int = 3 // Process every 3rd frame by default
    @Published var visionProcessingQuality: VisionQuality = .balanced
    @Published var enableAPIThrottling: Bool = false
    
    init() {
        setupPerformanceMonitoring()
        startOptimization()
    }
    
    deinit {
        performanceTimer?.invalidate()
    }
    
    private func setupPerformanceMonitoring() {
        // Monitor thermal state changes
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .sink { [weak self] _ in
                self?.thermalState = ProcessInfo.processInfo.thermalState
                self?.adjustProcessingLevel()
            }
            .store(in: &cancellables)
        
        // Monitor memory pressure (simplified for this implementation)
        // In a real app, you'd use dispatch_source_create with DISPATCH_SOURCE_TYPE_MEMORYPRESSURE
        Timer.publish(every: 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateMemoryPressure()
                self?.updateBatteryLevel()
            }
            .store(in: &cancellables)
    }
    
    private func startOptimization() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.optimizePerformance()
        }
    }
    
    private func optimizePerformance() {
        updateSystemMetrics()
        adjustProcessingLevel()
        optimizeFrameProcessing()
        optimizeMemoryUsage()
        
        logger.info("Performance optimization cycle completed - Level: \(self.currentProcessingLevel.rawValue)")
    }
    
    private func updateSystemMetrics() {
        thermalState = ProcessInfo.processInfo.thermalState
        updateMemoryPressure()
        updateBatteryLevel()
    }
    
    private func updateMemoryPressure() {
        // Simplified memory pressure detection for macOS
        let processInfo = ProcessInfo.processInfo
        
        // Use available system memory as a proxy for memory pressure
        let physicalMemory = processInfo.physicalMemory
        let memoryInGB = Double(physicalMemory) / (1024.0 * 1024.0 * 1024.0)
        
        // Simple heuristic based on available system memory
        if memoryInGB < 4.0 {
            memoryPressure = .critical
        } else if memoryInGB < 8.0 {
            memoryPressure = .warning
        } else {
            memoryPressure = .normal
        }
    }
    
    private func updateBatteryLevel() {
        // Get battery level using IOKit
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            // If battery info can't be retrieved, assume we're on AC power
            batteryLevel = 1.0
            logger.warning("Failed to get power source info")
            return
        }
        
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            
            if let capacity = description[kIOPSCurrentCapacityKey as String] as? Int,
               let maxCapacity = description[kIOPSMaxCapacityKey as String] as? Int,
               maxCapacity > 0 {
                batteryLevel = Double(capacity) / Double(maxCapacity)
                break
            }
        }
    }
    
    private func adjustProcessingLevel() {
        let oldLevel = currentProcessingLevel
        
        // Determine new processing level based on system state
        if isThermalStateHigh(thermalState) || 
           memoryPressure == .critical || 
           batteryLevel < 0.1 {
            currentProcessingLevel = .minimal
        } else if isThermalStateFair(thermalState) || 
                  memoryPressure >= memoryPressureThreshold || 
                  batteryLevel < batteryThreshold {
            currentProcessingLevel = .reduced
        } else if thermalState == .nominal && 
                  memoryPressure == .normal && 
                  batteryLevel > 0.5 {
            currentProcessingLevel = .optimal
        } else {
            currentProcessingLevel = .normal
        }
        
        if oldLevel != currentProcessingLevel {
            logger.info("Processing level changed from \(oldLevel.rawValue) to \(self.currentProcessingLevel.rawValue)")
            applyProcessingLevelChanges()
        }
    }
    
    private func applyProcessingLevelChanges() {
        switch currentProcessingLevel {
        case .minimal:
            frameProcessingInterval = 10
            visionProcessingQuality = .low
            enableAPIThrottling = true
            
        case .reduced:
            frameProcessingInterval = 6
            visionProcessingQuality = .balanced
            enableAPIThrottling = true
            
        case .normal:
            frameProcessingInterval = 3
            visionProcessingQuality = .balanced
            enableAPIThrottling = false
            
        case .optimal:
            frameProcessingInterval = 2
            visionProcessingQuality = .high
            enableAPIThrottling = false
        }
        
        // Notify other components of the change
        NotificationCenter.default.post(
            name: .performanceLevelChanged,
            object: self,
            userInfo: ["level": currentProcessingLevel]
        )
    }
    
    private func optimizeFrameProcessing() {
        // Intel Mac specific optimizations
        if ProcessInfo.processInfo.processorCount < 8 {
            // On lower-end Intel Macs, be more conservative
            frameProcessingInterval = max(frameProcessingInterval, 4)
        }
        
        // Adjust based on thermal state
        if isThermalStateFair(thermalState) {
            frameProcessingInterval = min(frameProcessingInterval + 2, 15)
        }
    }
    
    private func optimizeMemoryUsage() {
        if memoryPressure >= .warning {
            isOptimizing = true
            
            // Trigger memory cleanup
            DispatchQueue.global(qos: .utility).async {
                // Force garbage collection
                autoreleasepool {
                    // Clear caches and temporary data
                    self.clearCaches()
                }
                
                DispatchQueue.main.async {
                    self.isOptimizing = false
                }
            }
        }
    }
    
    private func clearCaches() {
        // Clear various caches to free memory
        URLCache.shared.removeAllCachedResponses()
        
        // Notify other components to clear their caches
        NotificationCenter.default.post(name: .shouldClearCaches, object: self)
        
        logger.info("Cleared caches due to memory pressure")
    }
    
    // MARK: - Public Interface
    
    func getOptimalProcessingInterval() -> Int {
        return frameProcessingInterval
    }
    
    func getVisionProcessingQuality() -> VisionQuality {
        return visionProcessingQuality
    }
    
    func shouldThrottleAPI() -> Bool {
        return enableAPIThrottling
    }
    
    func shouldReduceProcessing() -> Bool {
        return currentProcessingLevel <= .reduced
    }
    
    func getPerformanceMetrics() -> PerformanceMetrics {
        return PerformanceMetrics(
            thermalState: thermalState,
            memoryPressure: memoryPressure,
            batteryLevel: batteryLevel,
            processingLevel: currentProcessingLevel,
            frameInterval: frameProcessingInterval,
            visionQuality: visionProcessingQuality
        )
    }
    
    func forceOptimization() {
        logger.info("Force optimization requested")
        optimizePerformance()
    }
    
    // MARK: - Helper Methods
    
    private func isThermalStateHigh(_ state: ProcessInfo.ThermalState) -> Bool {
        return state == .serious || state == .critical
    }
    
    private func isThermalStateFair(_ state: ProcessInfo.ThermalState) -> Bool {
        return state == .fair || isThermalStateHigh(state)
    }
}

// MARK: - Supporting Types

enum ProcessingLevel: String, CaseIterable, Comparable {
    case minimal = "minimal"
    case reduced = "reduced"
    case normal = "normal"
    case optimal = "optimal"
    
    var description: String {
        switch self {
        case .minimal: return "Minimal processing to preserve battery/thermal"
        case .reduced: return "Reduced processing due to system constraints"
        case .normal: return "Normal processing level"
        case .optimal: return "Optimal processing with full features"
        }
    }
    
    static func < (lhs: ProcessingLevel, rhs: ProcessingLevel) -> Bool {
        let order: [ProcessingLevel] = [.minimal, .reduced, .normal, .optimal]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

enum MemoryPressure: String, CaseIterable, Comparable {
    case normal = "normal"
    case warning = "warning"
    case critical = "critical"
    
    static func < (lhs: MemoryPressure, rhs: MemoryPressure) -> Bool {
        let order: [MemoryPressure] = [.normal, .warning, .critical]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

enum VisionQuality: String, CaseIterable {
    case low = "low"
    case balanced = "balanced"
    case high = "high"
    
    var processingOptions: [String: Any] {
        switch self {
        case .low:
            return [
                "accuracy": "fast",
                "revision": 1
            ]
        case .balanced:
            return [
                "accuracy": "balanced",
                "revision": 2
            ]
        case .high:
            return [
                "accuracy": "high",
                "revision": 3
            ]
        }
    }
}

struct PerformanceMetrics {
    let thermalState: ProcessInfo.ThermalState
    let memoryPressure: MemoryPressure
    let batteryLevel: Double
    let processingLevel: ProcessingLevel
    let frameInterval: Int
    let visionQuality: VisionQuality
    
    var description: String {
        return """
        Performance Metrics:
        - Thermal: \(thermalState.description)
        - Memory: \(memoryPressure.rawValue)
        - Battery: \(String(format: "%.1f%%", batteryLevel * 100))
        - Processing: \(processingLevel.rawValue)
        - Frame Interval: \(frameInterval)
        - Vision Quality: \(visionQuality.rawValue)
        """
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let performanceLevelChanged = Notification.Name("performanceLevelChanged")
    static let shouldClearCaches = Notification.Name("shouldClearCaches")
}

// MARK: - ProcessInfo.ThermalState Extension

private extension ProcessInfo.ThermalState {
    var description: String {
        switch self {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }
}