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

import SwiftUI
import Combine

struct DashboardView: View {
    @ObservedObject var activityManager: ActivityTrackingManager
    @ObservedObject var cameraManager: CameraTrackingManager
    @ObservedObject var spotifyService: SpotifyService
    @State private var insights: String = "Collecting data to generate insights..."
    @State private var showingPermissionAlert = false
    @State private var showMusicRecommendations = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Focus")
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
            
            // Music Control Section
            MusicControlBar(
                spotifyService: spotifyService,
                activityManager: activityManager
            )
            
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
            
            // Attention Distribution Chart
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
                                .fill(stateColor(for: state))
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
                HStack {
                    Text("AI Insights")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        // Request new insights
                        let service = OpenAIService(apiKey: "YOUR_OPENAI_API_KEY")
                        service.analyzeAttentionPatterns(
                            records: activityManager.attentionHistory,
                            currentState: activityManager.currentState,
                            musicActive: spotifyService.isPlaying
                        ) { result in
                            self.insights = result
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Refresh insights")
                }
                
                Text(insights)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
            }
            .padding()
            
            // Action Buttons
            HStack {
                if activityManager.currentState == .inFocus || activityManager.currentState == .lowFocus {
                    actionButton(
                        title: "Need Music?",
                        icon: "music.note",
                        action: {
                            showMusicRecommendations = true
                        }
                    )
                }
                
                if activityManager.currentState == .distracted {
                    actionButton(
                        title: "Refocus",
                        icon: "target",
                        action: {
                            // Start a quick refocus timer
                            // This would be implemented in the full version
                        }
                    )
                }
                
                if activityManager.currentState == .awayFromScreen || activityManager.currentState == .idle {
                    actionButton(
                        title: "Back to Work",
                        icon: "arrow.right.circle",
                        action: {
                            // Trigger a notification or alert to help user return to work
                            // This would be implemented in the full version
                        }
                    )
                }
                
                if spotifyService.isAuthorized && !spotifyService.isPlaying {
                    actionButton(
                        title: "Start Music",
                        icon: "play.circle",
                        action: {
                            showMusicRecommendations = true
                        }
                    )
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 500, minHeight: 700)
        .sheet(isPresented: $showMusicRecommendations) {
            VStack(spacing: 20) {
                Text("Music Recommendations")
                    .font(.title)
                    .padding(.top)
                
                Text("For \(activityManager.currentState.icon) \(activityManager.currentState.rawValue)")
                    .font(.headline)
                
                Divider()
                
                if spotifyService.recommendedPlaylists.isEmpty {
                    VStack {
                        ProgressView()
                            .padding()
                        Text("Loading recommendations...")
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(spotifyService.getPlaylistsForAttentionState(activityManager.currentState).prefix(6)) { playlist in
                                RecommendedPlaylistRow(playlist: playlist) {
                                    spotifyService.playPlaylist(playlist)
                                    showMusicRecommendations = false
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                if !spotifyService.isAuthorized {
                    Button("Connect to Spotify") {
                        if let url = spotifyService.getAuthorizationURL() {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .padding()
                }
                
                Button("Close") {
                    showMusicRecommendations = false
                }
                .padding()
            }
            .frame(width: 400, height: 500)
        }
        .onAppear {
            // Request insights when dashboard appears
            let service = OpenAIService()
            service.analyzeAttentionPatterns(
                records: activityManager.attentionHistory,
                currentState: activityManager.currentState,
                musicActive: spotifyService.isPlaying
            ) { result in
                self.insights = result
            }
            
            // Check Spotify authorization status
            if spotifyService.isAuthorized {
                spotifyService.fetchRecommendedPlaylists()
            }
        }
    }
    
    // Helper function for action buttons
    func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 15)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.1)))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Helper function for state colors
    func stateColor(for state: AttentionState) -> Color {
        switch state {
        case .inFocus: return Color.green
        case .lowFocus: return Color.blue
        case .distracted: return Color.orange
        case .phoneInHand: return Color.red
        case .awayFromScreen: return Color.purple
        case .idle: return Color.gray
        }
    }
}

struct RecommendedPlaylistRow: View {
    let playlist: SpotifyPlaylist
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                // Playlist image placeholder (can be replaced with actual image)
                AsyncImage(url: URL(string: playlist.images[0].url)) {image
                    in image.resizable()
                }
                
                placeholder: {
                    
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "music.note")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(playlist.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(playlist.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
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

#if DEBUG
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        // Create mock instances of your services
        let activityManager = {
            let manager = ActivityTrackingManager()
            // Add some mock data
            manager.currentState = .inFocus
            manager.stateStartTime = Date().addingTimeInterval(-360) // 6 minutes ago
            
            // Add some mock history records
            let states: [AttentionState] = [.inFocus, .distracted, .lowFocus, .phoneInHand, .idle]
            for i in 0..<10 {
                let record = AttentionRecord(
                    timestamp: Date().addingTimeInterval(Double(-i * 300)), // 5 min intervals
                    state: states[i % states.count],
                    duration: Double.random(in: 60...300),
                    activeApp: ["Xcode", "Safari", "Messages", "Mail", "Preview"][i % 5]
                )
                manager.attentionHistory.append(record)
            }
            
            return manager
        }()
        
        let cameraManager = {
            let manager = CameraTrackingManager()
            manager.isEnabled = true
            manager.processingActive = true
            manager.isFaceDetected = true
            manager.isLookingAtScreen = true
            return manager
        }()
        
        let spotifyService = {
            let service = SpotifyService()
            
            // Add mock data
            service.isAuthorized = true
            service.isPlaying = true
            service.currentTrack = SpotifyTrack(
                id: "123",
                name: "Focus Flow",
                artists: [SpotifyArtist(id: "456", name: "Ambient Works")],
                album: SpotifyAlbum(name: "Deep Focus", images: [])
            )
            
            // Add mock playlists
            service.recommendedPlaylists = [
                SpotifyPlaylist(
                    id: "playlist1",
                    name: "Deep Focus",
                    description: "Instrumental concentration music",
                    images: [],
                    uri: "spotify:playlist:123"
                ),
                SpotifyPlaylist(
                    id: "playlist2",
                    name: "Ambient Focus",
                    description: "Background music for productivity",
                    images: [],
                    uri: "spotify:playlist:456"
                ),
                SpotifyPlaylist(
                    id: "playlist3",
                    name: "Coding Mix",
                    description: "Perfect for programming sessions",
                    images: [],
                    uri: "spotify:playlist:789"
                )
            ]
            
            return service
        }()
        
        return DashboardView(
            activityManager: activityManager,
            cameraManager: cameraManager,
            spotifyService: spotifyService
        )
        .frame(width: 600, height: 800) // Set dimensions for preview
        .preferredColorScheme(.light)
    }
}
#endif

