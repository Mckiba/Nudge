//
//  Settings.swift
//  Tracky
//
//  Created by McKiba Williams on 4/13/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showCode: Bool = false
    @State private var showSuggestions: Bool = true
    @State private var language: LanguageOption = .autoDetect
    @ObservedObject var activityManager: ActivityTrackingManager
    @ObservedObject var cameraManager: CameraTrackingManager
    @State private var showingPermissionAlert = false

    
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.black)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        Text("Settings")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.gray.opacity(0.3))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // Content
                    HStack(spacing: 0) {
                        // Sidebar
                        VStack(alignment: .leading, spacing: 5) {
                            SidebarItem(icon: "gearshape", text: "General", isSelected: true)
                            SidebarItem(icon: "bell", text: "Notifications")
                            SidebarItem(icon: "person", text: "Personalization")
                            SidebarItem(icon: "waveform", text: "Speech")
                            SidebarItem(icon: "shield", text: "Data controls")
                            SidebarItem(icon: "app.connected.to.app.below.fill", text: "Connected apps")
                            SidebarItem(icon: "lock", text: "Security")
                            SidebarItem(icon: "star", text: "Subscription")
                        }
                        .padding(.vertical)
                        .frame(width: 250)
                        .background(Color.black)
                        
                        // Divider
                        Rectangle()
                            .frame(width: 1)
                            .foregroundColor(Color.gray.opacity(0.3))
                        
                        // Main Settings Area
                        ScrollView {
                            VStack(alignment: .leading, spacing: 30) {
                                // Theme
                                SettingsSection(title: "Theme") {
                                    Menu {
                                        Button("System", action: {})
                                        Button("Light", action: {})
                                        Button("Dark", action: {})
                                    } label: {
                                        HStack {
                                            Text("System")
                                                .foregroundColor(.white)
                                            Spacer()
                                            Image(systemName: "chevron.down")
                                                .foregroundColor(.white)
                                        }
                                        .padding()
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                }
                                
                                // Toggle switches
                                Toggle("Always show code when using data analyst", isOn: $showCode)
                                    .padding(.horizontal)
                                    .foregroundColor(.white)
                                
                                Toggle("Show follow up suggestions in chats", isOn: $showSuggestions)
                                    .padding(.horizontal)
                                    .foregroundColor(.white)
                                
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
                                
                                Divider()
                                    .background(Color.gray.opacity(0.3))
                                
                                // Language
                                SettingsSection(title: "Language") {
                                    Menu {
                                        Button("Auto-detect", action: { language = .autoDetect })
                                        Button("English", action: { language = .english })
                                        Button("Spanish", action: { language = .spanish })
                                    } label: {
                                        HStack {
                                            Text(language.rawValue)
                                                .foregroundColor(.white)
                                            Spacer()
                                            Image(systemName: "chevron.down")
                                                .foregroundColor(.white)
                                        }
                                        .padding()
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                }
                                
                                Divider()
                                    .background(Color.gray.opacity(0.3))
                                
                     
                                
                                // Log out
                                SettingsSection(title: "Log out on this device") {
                                    Button(action: {}) {
                                        Text("Log out")
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 30)
                                            .padding(.vertical, 10)
                                            .background(Color.gray.opacity(0.2))
                                            .cornerRadius(20)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding()
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Supporting Views
struct SidebarItem: View {
    let icon: String
    let text: String
    var isSelected: Bool = false
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 24, height: 24)
            Text(text)
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 15)
        .background(isSelected ? Color.gray.opacity(0.3) : Color.clear)
        .cornerRadius(8)
        .foregroundColor(.white)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            content
        }
    }
}

// MARK: - Supporting Types
enum LanguageOption: String {
    case autoDetect = "Auto-detect"
    case english = "English"
    case spanish = "Spanish"
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(activityManager: ActivityTrackingManager(), cameraManager: CameraTrackingManager())
            .preferredColorScheme(.dark)
    }
}
