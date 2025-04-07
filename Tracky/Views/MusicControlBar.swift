//
//  MusicControlBar.swift
//  Tracky
//
//  Created by McKiba Williams on 4/5/25.
//

import SwiftUI

// MARK: - Music Control Bar

struct MusicControlBar: View {
    @ObservedObject var spotifyService: SpotifyService
    @ObservedObject var activityManager: ActivityTrackingManager
    @State private var showRecommendations = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Focus Music")
                    .font(.headline)
                
                Spacer()
                
                if spotifyService.isAuthorized {
                    Button(action: {
                        showRecommendations.toggle()
                    }) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Show recommendations")
                } else {
                    Button("Connect Spotify") {
                        if let url = spotifyService.getAuthorizationURL() {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.link)
                    
                    Button("Debug Auth") {
                        print("DEBUG: Testing Spotify auth state")
                        print("DEBUG: isAuthorized = \(spotifyService.isAuthorized)")
                        spotifyService.debugCheckAuthorization()
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                }
            }
            
            if spotifyService.isAuthorized {
                // Current track display
                if let track = spotifyService.currentTrack {
                    HStack(spacing: 10) {
                        AsyncImage(url: URL(string: track.album.images[0].url)) {image
                            in image.resizable()
                        }
                        
                        placeholder: {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.3))
                        }                                .frame(width: 50, height: 50)

                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.name)
                                .font(.system(size: 13))
                                .lineLimit(1)
                            
                            Text(track.artists.map { $0.name }.joined(separator: ", "))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                    }
                } else {
                    Text("Not playing")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                // Music controls
                HStack(spacing: 20) {
                    Button(action: {
                        spotifyService.previousTrack()
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        spotifyService.togglePlayPause()
                    }) {
                        Image(systemName: spotifyService.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        spotifyService.nextTrack()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    Button(action: {
                        // Get recommendations for current attention state
                        showRecommendations.toggle()
                    }) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Get recommendations for current state")
                }
                .padding(.horizontal, 5)
                
                // Playlist recommendations (when active)
                if showRecommendations {
                    PlaylistRecommendations(
                        spotifyService: spotifyService,
                        activityManager: activityManager,
                        isShowing: $showRecommendations
                    )
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
    }
}

// MARK: - Playlist Recommendations

struct PlaylistRecommendations: View {
    @ObservedObject var spotifyService: SpotifyService
    @ObservedObject var activityManager: ActivityTrackingManager
    @Binding var isShowing: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recommended for \(activityManager.currentState.rawValue)")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    isShowing = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Divider()
            
            let playlists = spotifyService.getPlaylistsForAttentionState(activityManager.currentState)
            
            if playlists.isEmpty {
                Text("Loading recommendations...")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(playlists.prefix(5)) { playlist in
                            PlaylistRow(playlist: playlist) {
                                spotifyService.playPlaylist(playlist)
                                isShowing = false
                            }
                        }
                    }
                }
                .frame(height: min(CGFloat(playlists.count) * 60, 200))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.2)))
    }
}

// MARK: - Playlist Row

struct PlaylistRow: View {
    let playlist: SpotifyPlaylist
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Playlist image placeholder
                
                AsyncImage(url: URL(string: playlist.images[0].url)) {image
                    in image.resizable()
                }
                
                placeholder: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                }                                .frame(width: 50, height: 50)

                
              
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.name)
                        .font(.system(size: 13))
                        .lineLimit(1)
                    
                    Text(playlist.description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "play.circle")
                    .font(.system(size: 14))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 4)
    }
}


