//
//  Dashboard.swift
//  Tracky
//
//  Created by McKiba Williams on 4/5/25.
//

import AppKit
import Foundation
import Combine
import SwiftUI
import SwiftUICore

struct DashboardView: View {
    @ObservedObject var activityManager: ActivityTrackingManager
    @ObservedObject var cameraManager: CameraTrackingManager
    @State private var insights: String = "Collecting data to generate insights..."
    @State private var showingPermissionAlert = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Attention Dashboard")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Current State Section
            HStack {
                VStack(alignment: .leading) {
                    Text("Current State:")
                    Text("\(activityManager.currentState.icon) \(activityManager.currentState.rawValue)")
                        .font(.title)
                        .foregroundColor(.blue)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Duration:")
                    Text("\(Int(-activityManager.stateStartTime.timeIntervalSinceNow))s")
                        .font(.title)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
            
            // Camera Tracking Controls
            VStack(alignment: .leading) {
                HStack {
                    Text("Camera Tracking")
                        .font(.headline)
                    
                    Spacer()
                    
                    Toggle("", isOn: $cameraManager.processingActive)
                        .labelsHidden()
                        .onChange(of: cameraManager.processingActive) { newValue in
                            if newValue {
                                if !cameraManager.isEnabled {
                                    cameraManager.requestPermissionAndSetup { success in
                                        if !success {
                                            showingPermissionAlert = true
                                            cameraManager.processingActive = false
                                        }
                                    }
                                } else {
                                    cameraManager.startTracking()
                                }
                            } else {
                                cameraManager.stopTracking()
                            }
                        }
                }
                
                if cameraManager.processingActive {
                    HStack(spacing: 15) {
                        StatusIndicator(
                            title: "Face Detected",
                            isActive: cameraManager.isFaceDetected,
                            color: .green
                        )
                        
                        StatusIndicator(
                            title: "Looking at Screen",
                            isActive: cameraManager.isLookingAtScreen,
                            color: .blue
                        )
                        
                        StatusIndicator(
                            title: "Phone Detected",
                            isActive: cameraManager.isHoldingPhone,
                            color: .orange
                        )
                    }
                    .padding(.top, 5)
                } else {
                    Text("Enable camera tracking for enhanced attention detection")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 5)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
            .alert(isPresented: $showingPermissionAlert) {
                Alert(
                    title: Text("Camera Permission Required"),
                    message: Text("This feature needs camera access to detect your presence and attention. Please enable camera access in System Preferences."),
                    primaryButton: .default(Text("Open Settings")) {
                        if let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                            NSWorkspace.shared.open(settingsURL)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
            
            // Simple bar chart for attention distribution
            VStack(alignment: .leading) {
                Text("Last Hour Distribution")
                    .font(.headline)
                
                ForEach(AttentionState.allCases, id: \.self) { state in
                    let distribution = activityManager.getStateDistribution()
                    let totalTime: TimeInterval = distribution.values.reduce(0, +)
                    let stateTime = distribution[state] ?? 0
                    let percentage = totalTime > 0 ? stateTime / totalTime : 0
                    
                    HStack {
                        Text("\(state.icon) \(state.rawValue)")
                            .frame(width: 150, alignment: .leading)
                        
                        GeometryReader { geometry in
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.blue)
                                .frame(width: geometry.size.width * CGFloat(percentage), height: 20)
                        }
                        .frame(height: 20)
                        
                        Text("\(Int(stateTime / 60)) min")
                            .frame(width: 60, alignment: .trailing)
                    }
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
            
            // AI Insights section
            VStack(alignment: .leading) {
                Text("AI Insights")
                    .font(.headline)
                
                Text(insights)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
            }
            .padding()
            
            Spacer()
        }
        .padding()
        .frame(width: 500, height: 700)
        .onAppear {
            // Request insights when dashboard appears
            let service = OpenAIService(apiKey: "YOUR_API_KEY")
            service.analyzeAttentionPatterns(records: activityManager.attentionHistory) { result in
                self.insights = result
            }
        }
    }
}

// MARK: - Status Indicator Component

struct StatusIndicator: View {
    let title: String
    let isActive: Bool
    let color: Color
    
    var body: some View {
        VStack {
            Circle()
                .fill(isActive ? color : Color.gray)
                .frame(width: 12, height: 12)
            Text(title)
                .font(.caption)
                .foregroundColor(isActive ? .primary : .secondary)
        }
    }
}

