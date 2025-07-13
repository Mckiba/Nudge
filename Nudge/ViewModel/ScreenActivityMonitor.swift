import Foundation
import Cocoa
import ApplicationServices
import Combine
import IOKit.ps
import IOKit

class ScreenActivityMonitor: ObservableObject {
    @Published var activeApplication: String = ""
    @Published var activeWebsite: String?
    @Published var windowCount: Int = 0
    @Published var isFullscreen: Bool = false
    @Published var screenBrightness: Double = 0.5
    @Published var keyboardActivity: Int = 0
    @Published var mouseMovement: Double = 0.0
    
    private var activityTimer: Timer?
    private var keyboardEventTap: CFMachPort?
    private var mouseEventTap: CFMachPort?
    
    private var lastMousePosition: CGPoint = .zero
    private var mouseMovementAccumulator: Double = 0.0
    private var keyboardActivityCount: Int = 0
    private var permissionAlertShown: Bool = false
    
    private let monitoringInterval: TimeInterval = 1.0
    private var isMonitoringActive = false
    
    init() {
        requestAccessibilityPermissions()
        // Don't start monitoring automatically - wait for startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    private func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !trusted {
            print("Accessibility permissions required for screen activity monitoring")
        }
    }
    
    func startMonitoring() {
        guard !isMonitoringActive else { return }
        
        stopMonitoring() // Ensure we don't have duplicate timers
        isMonitoringActive = true
                
        activityTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            self?.updateActivityMetrics()
        }
        
        setupInputMonitoring()
    }
    
    func stopMonitoring() {
        isMonitoringActive = false
        
        activityTimer?.invalidate()
        activityTimer = nil
        
        teardownInputMonitoring()
    }
    
    private func setupInputMonitoring() {
        // Monitor keyboard activity
        let keyboardEventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        keyboardEventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: keyboardEventMask,
            callback: { _, _, event, refcon in
                let monitor = Unmanaged<ScreenActivityMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                monitor.keyboardActivityCount += 1
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        // Monitor mouse movement
        let mouseEventMask = CGEventMask(1 << CGEventType.mouseMoved.rawValue)
        mouseEventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mouseEventMask,
            callback: { _, _, event, refcon in
                let monitor = Unmanaged<ScreenActivityMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                let location = event.location
                monitor.updateMouseMovement(location)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        if let keyboardTap = keyboardEventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, keyboardTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: keyboardTap, enable: true)
        }
        
        if let mouseTap = mouseEventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, mouseTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: mouseTap, enable: true)
        }
    }
    
    private func teardownInputMonitoring() {
        if let keyboardTap = keyboardEventTap {
            CGEvent.tapEnable(tap: keyboardTap, enable: false)
            CFMachPortInvalidate(keyboardTap)
        }
        
        if let mouseTap = mouseEventTap {
            CGEvent.tapEnable(tap: mouseTap, enable: false)
            CFMachPortInvalidate(mouseTap)
        }
        
        keyboardEventTap = nil
        mouseEventTap = nil
    }
    
    private func updateMouseMovement(_ currentPosition: CGPoint) {
        if lastMousePosition != .zero {
            let deltaX = currentPosition.x - lastMousePosition.x
            let deltaY = currentPosition.y - lastMousePosition.y
            let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
            mouseMovementAccumulator += Double(distance)
        }
        lastMousePosition = currentPosition
    }
    
    private func updateActivityMetrics() {
        DispatchQueue.main.async { [weak self] in
            self?.updateActiveApplication()
            self?.updateWindowMetrics()
            self?.updateScreenBrightness()
            self?.updateInputActivity()
        }
    }
    
    private func updateActiveApplication() {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else { return }
        
        let appName = frontmostApp.localizedName ?? "Unknown"
        activeApplication = appName
        
        // Try to extract website information for browsers
        if isBrowserApplication(appName) {
            print("DEBUG: Detected browser: \(appName)")
            let website = extractWebsiteFromBrowser(appName)
            activeWebsite = website
            print("DEBUG: Extracted website: \(website ?? "nil")")
        } else {
            activeWebsite = nil
        }
    }
    
    private func isBrowserApplication(_ appName: String) -> Bool {
        let browsers = ["Safari", "Chrome", "Firefox", "Edge", "Opera", "Brave"]
        return browsers.contains { appName.contains($0) }
    }
    
 
    
    private func extractWebsiteFromBrowser(_ browserName: String) -> String? {
        guard isBrowserRunning(browserName) else {
            print("DEBUG: Browser \(browserName) not running")
            return nil
        }
        
        // Try AppleScript first (most reliable)
        if let website = extractWebsiteViaAppleScript(browserName) {
            return website
        }
        

        
        print("DEBUG: Could not extract website using any method")
        return nil
    }

    private func extractWebsiteViaAppleScript(_ browserName: String) -> String? {
        // Check if we have automation permission first
        if !hasAutomationPermission(for: browserName) {
            print("DEBUG: No automation permission for \(browserName)")
            requestAutomationPermission(for: browserName)
            return nil
        }
        
        guard let scriptText = getScriptText(browserName) else {
            print("DEBUG: No script available for \(browserName)")
            return nil
        }
        
        var error: NSDictionary?
        
        guard let script = NSAppleScript(source: scriptText) else {
            print("DEBUG: Could not create AppleScript")
            return nil
        }
        
        let result = script.executeAndReturnError(&error)
        
        if let error = error {
            let errorNumber = error["NSAppleScriptErrorNumber"] as? Int ?? 0
            print("DEBUG: AppleScript error \(errorNumber) for \(browserName): \(error.description)")
            
            // Don't log common errors (app not running, no windows, permission denied)
            if errorNumber != -600 && errorNumber != -1728 && errorNumber != -10004 {
                print("AppleScript execution failed: \(error.description)")
            }
            return nil
        }
        
        guard let outputString = result.stringValue else {
            print("DEBUG: AppleScript returned no string value")
            return nil
        }
        
        print("DEBUG: AppleScript raw output: '\(outputString)'")
        
        // Handle empty string case
        let trimmedOutput = outputString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedOutput.isEmpty {
            print("DEBUG: Empty URL from AppleScript")
            return nil
        }
        
        // Parse the URL
        if let url = URL(string: trimmedOutput),
           var host = url.host {
            if host.hasPrefix("www.") {
                host = String(host.dropFirst(4))
            }
            let resultURL = "\(host)\(url.path)"
            print("DEBUG: Final processed URL: '\(resultURL)'")
            return resultURL
        } else {
            print("DEBUG: Failed to parse URL from: '\(trimmedOutput)'")
            return nil
        }
    }

    private func hasAutomationPermission(for browserName: String) -> Bool {
        let testScript: String
        
        if browserName.contains("Safari") {
            testScript = "tell application \"Safari\" to get name"
        } else if browserName.contains("Chrome") {
            testScript = "tell application \"Google Chrome\" to get name"
        } else {
            return false
        }
        
        var error: NSDictionary?
        let script = NSAppleScript(source: testScript)
        script?.executeAndReturnError(&error)
        
        if let error = error {
            let errorNumber = error["NSAppleScriptErrorNumber"] as? Int ?? 0
            return errorNumber != -10004 && errorNumber != -1743
        }
        
        return true
    }

    private func requestAutomationPermission(for browserName: String) {
        // Only show the alert once per session
        guard !permissionAlertShown else { return }
        permissionAlertShown = true
        
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Browser Access Permission Required"
            alert.informativeText = """
            To track website activity, Nudge needs permission to access \(browserName).
            
            Please:
            1. Open System Preferences/Settings
            2. Go to Security & Privacy → Privacy → Automation
            3. Find "Nudge" and enable access to "\(browserName)"
            4. Try your focus session again
            
            This allows Nudge to identify distracting websites during focus sessions.
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open System Preferences")
            alert.addButton(withTitle: "Continue Without Website Tracking")
            
            let response = alert.runModal()
            
            if response == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    func getScriptText(_ appName: String) -> String? {
        print("DEBUG: Getting script for app: \(appName)")
        
        if appName.contains("Chrome") {
            return """
            tell application "Google Chrome"
                if (count of windows) > 0 then
                    if (count of tabs of window 1) > 0 then
                        return URL of active tab of window 1
                    else
                        return ""
                    end if
                else
                    return ""
                end if
            end tell
            """
        } else if appName.contains("Safari") {
            return """
            tell application "Safari"
                if (count of documents) > 0 then
                    return URL of front document
                else
                    return ""
                end if
            end tell
            """
        } else {
            print("DEBUG: No script available for app: \(appName)")
            return nil
        }
    }
    
    
    
    
    private func isBrowserRunning(_ browserName: String) -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains { app in
            if let appName = app.localizedName {
                return (browserName.contains("Chrome") && appName.contains("Chrome")) ||
                       (browserName.contains("Safari") && appName.contains("Safari")) ||
                       (browserName.contains("Firefox") && appName.contains("Firefox")) ||
                       (browserName.contains("Edge") && appName.contains("Edge"))
            }
            return false
        }
        print("DEBUG: Browser \(browserName) running: \(isRunning)")
        return isRunning
    }
    
    
    private func updateWindowMetrics() {
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return
        }
        
        let visibleWindows = windowList.filter { window in
            guard let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0 else { return false } // Only normal windows
            
            return true
        }
        
        windowCount = visibleWindows.count
        
        // Check for fullscreen windows
        isFullscreen = visibleWindows.contains { window in
            guard let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let width = bounds["Width"] as? CGFloat,
                  let height = bounds["Height"] as? CGFloat else { return false }
            
            let screenSize = NSScreen.main?.frame.size ?? .zero
            return width >= screenSize.width && height >= screenSize.height
        }
    }
    
    private func updateScreenBrightness() {
        // Simplified screen brightness detection for macOS
        // In a real implementation, you might use private APIs or CoreDisplay framework
        // For now, we'll use a heuristic based on system preferences
        
        // Check if it's likely dark mode (which often correlates with lower brightness)
        let isDarkMode = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        
        // Estimate brightness based on time of day and system appearance
        let hour = Calendar.current.component(.hour, from: Date())
        var estimatedBrightness: Double = 0.7 // Default brightness
        
        if isDarkMode {
            estimatedBrightness = 0.4
        }
        
        // Adjust for time of day
        if hour < 7 || hour > 20 {
            estimatedBrightness *= 0.6 // Dimmer at night
        } else if hour >= 10 && hour <= 16 {
            estimatedBrightness *= 1.2 // Brighter during day
        }
        
        screenBrightness = min(estimatedBrightness, 1.0)
    }
    
    private func updateInputActivity() {
        keyboardActivity = keyboardActivityCount
        mouseMovement = mouseMovementAccumulator
        
        // Reset counters for next interval
        keyboardActivityCount = 0
        mouseMovementAccumulator = 0.0
    }
    
    func getCurrentContextualData() -> ContextualData {
        return ContextualData(
            timestamp: Date(),
            activeApplication: activeApplication,
            activeWebsite: activeWebsite,
            screenBrightness: screenBrightness,
            ambientLightLevel: 0.5, // Would need additional sensors
            thermalState: ProcessInfo.processInfo.thermalState.description,
            batteryLevel: getBatteryLevel(),
            isFullscreen: isFullscreen,
            windowCount: windowCount,
            keyboardActivity: keyboardActivity,
            mouseMovement: mouseMovement
        )
    }
    
    private func getBatteryLevel() -> Double {
        // Get battery level using IOKit
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        
        for source in sources {
            let description = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue()
            
            if let capacity = (description as NSDictionary)[kIOPSCurrentCapacityKey] as? Int,
               let maxCapacity = (description as NSDictionary)[kIOPSMaxCapacityKey] as? Int,
               maxCapacity > 0 {
                return Double(capacity) / Double(maxCapacity)
            }
        }
        
        return 1.0 // Default to full battery if unable to determine
    }
}

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
