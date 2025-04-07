//
//  ActivityTrackingManager.swift
//  Tracky
//
//  Created by McKiba Williams on 4/5/25.
//

import Foundation
import SwiftUI
import Combine
import AVFoundation
import Vision
import CoreImage


// MARK: - Activity Tracking Manager

class ActivityTrackingManager: ObservableObject {
    @Published var currentState: AttentionState = .idle
    @Published var stateStartTime: Date = Date()
    @Published var attentionHistory: [AttentionRecord] = []
    
    private var activeAppObserver: NSObjectProtocol?
    private var idleTimer: Timer?
    private var lastActiveApp: String?
    private var focusApps: Set<String> = ["Xcode", "Visual Studio Code", "Terminal", "Tracky"]
    private var distractionApps: Set<String> = ["Messages", "Mail", "Safari"]
    
    init() {
        setupObservers()
        startIdleDetection()
    }
    
    private func setupObservers() {
        // Observe application switching
        activeAppObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main) { [weak self] notification in
                guard let self = self else { return }
                if let app = notification.userInfo?["NSWorkspaceApplicationKey"] as? NSRunningApplication,
                   let appName = app.localizedName {
                    self.handleAppSwitch(appName)
                }
            }
        
        // Setup idle time detection
        startIdleDetection()
    }
    
    private func startIdleDetection() {
        idleTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Use CGEventSourceSecondsSinceLastEventType with a specific event type
            // We can use .keyDown as an example event type to check
            let keyboardIdleTime = CGEventSource.secondsSinceLastEventType(
                .combinedSessionState,
                eventType: .keyDown
            )
            
            let mouseIdleTime = CGEventSource.secondsSinceLastEventType(
                .combinedSessionState,
                eventType: .leftMouseDown
            )
            
            // Use the minimum idle time between keyboard and mouse
            let idleTime = min(keyboardIdleTime, mouseIdleTime)
            
            if idleTime > 300 { // 5 minutes
                self.updateState(.awayFromScreen)
            } else if idleTime > 60 { // 1 minute
                self.updateState(.idle)
            }
        }
    }
    
    private func handleAppSwitch(_ appName: String) {
        lastActiveApp = appName
        
        // Detect state based on app
        if focusApps.contains(appName) {
            updateState(.inFocus)
        } else if distractionApps.contains(appName) {
            updateState(.distracted)
        } else {
            // Default to low focus for other apps
            updateState(.lowFocus)
        }
    }
    
    private func updateState(_ newState: AttentionState) {
        // Only record a change if state is different
        if newState != currentState {
            // Record the previous state duration
            let now = Date()
            let duration = now.timeIntervalSince(stateStartTime)
            
            let record = AttentionRecord(
                timestamp: stateStartTime,
                state: currentState,
                duration: duration,
                activeApp: lastActiveApp
            )
            
            attentionHistory.append(record)
            
            // Update to new state
            currentState = newState
            stateStartTime = now
            
            // Notify if distracted for too long
            if newState == .distracted {
                scheduleDistractionAlert()
            }
            
            NotificationCenter.default.post(
                name: Notification.Name("AttentionStateChanged"),
                object: nil,
                userInfo: ["state": newState]
            )
        }
    }
    
    private func scheduleDistractionAlert() {
        // Schedule a notification if user remains distracted
        DispatchQueue.main.asyncAfter(deadline: .now() + 120) { [weak self] in
            guard let self = self, self.currentState == .distracted else { return }
            
            let notification = NSUserNotification()
            notification.title = "Focus Reminder"
            notification.informativeText = "You've been distracted for 2 minutes. Ready to refocus?"
            NSUserNotificationCenter.default.deliver(notification)
        }
    }
    
    func getStateDistribution(for timeframe: TimeInterval = 3600) -> [AttentionState: TimeInterval] {
        let cutoffTime = Date().addingTimeInterval(-timeframe)
        let relevantRecords = attentionHistory.filter { $0.timestamp >= cutoffTime }
        
        var distribution: [AttentionState: TimeInterval] = [:]
        for state in AttentionState.allCases {
            distribution[state] = 0
        }
        
        for record in relevantRecords {
            distribution[record.state, default: 0] += record.duration
        }
        
        return distribution
    }
}

// MARK: - Extended ActivityTrackingManager with Camera Integration

extension ActivityTrackingManager {
    func integrateCamera(_ cameraManager: CameraTrackingManager) {
        // Set up observation of camera tracking state
        cameraManager.$isFaceDetected.sink { [weak self] isFaceDetected in
            guard let self = self else { return }
            
            if !isFaceDetected && self.currentState != .awayFromScreen {
                self.updateState(.awayFromScreen)
            }
        }.store(in: &cancellables)
        
        cameraManager.$isLookingAtScreen.sink { [weak self] isLookingAtScreen in
            guard let self = self else { return }
            
            // Only update state if we're already tracking computer activity
            if self.currentState != .awayFromScreen {
                if isLookingAtScreen {
                    // Don't change state if already in focus or lowFocus
                    if ![.inFocus, .lowFocus].contains(self.currentState) {
                        self.determineStateFromActivity()
                    }
                } else {
                    // If not looking at screen but computer is active, might be distracted
                    if self.currentState != .distracted {
                        self.updateState(.distracted)
                    }
                }
            }
        }.store(in: &cancellables)
        
        cameraManager.$isHoldingPhone.sink { [weak self] isHoldingPhone in
            guard let self = self else { return }
            
            if isHoldingPhone && self.currentState != .phoneInHand {
                self.updateState(.phoneInHand)
            } else if !isHoldingPhone && self.currentState == .phoneInHand {
                self.determineStateFromActivity()
            }
        }.store(in: &cancellables)
    }
    
    private func determineStateFromActivity() {
        // Recompute state based on current activity
        // This is called when camera data suggests we need to reassess state
        // Implementation depends on your activity tracking logic
        if let app = lastActiveApp {
            if focusApps.contains(app) {
                updateState(.inFocus)
            } else if distractionApps.contains(app) {
                updateState(.distracted)
            } else {
                updateState(.lowFocus)
            }
        }
    }
}

private var cancellables = Set<AnyCancellable>()
