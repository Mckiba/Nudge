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
    @State private var showMusicRecommendations = false
    @State private var selectedDate = Date()
    
    var body: some View {
        
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("Focus")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    MenuBar(activityManager: activityManager, cameraManager: cameraManager)
                }
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
                
                HStack(alignment: .top) {
                    // Attention Distribution Chart
                    VStack {
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
                        
                        // AI Insights section
                        FocusInsights(
                            activityManager: activityManager, spotifyService: spotifyService
                        )
                        Spacer()
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
                    
                    HStack {
                        MonthlyCalendarView(selectedDate: $selectedDate)
                            .frame(width: 300, height: 400)
                            .padding()
                        
                        CalendarEvents(selectedDate: selectedDate)
                    }
                }.frame(alignment: .top)
                
            
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
