//
//  ContentView.swift
//  Tracky
//
//  Created by McKiba Williams on 7/9/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var activityManager = ActivityTrackingManager()
    @StateObject private var cameraManager = CameraTrackingManager()
    @StateObject private var spotifyService = SpotifyService()
    
    var body: some View {
        NavigationStack {
            DashboardView(
                activityManager: activityManager,
                cameraManager: cameraManager,
                spotifyService: spotifyService
            )
            .navigationTitle("Tracky")
        }
        .onAppear {
            activityManager.integrateCamera(cameraManager)
            
            // Set up notification observer for Spotify callback URL
            NotificationCenter.default.addObserver(forName: NSNotification.Name("SpotifyCallbackURL"), 
                                                   object: nil, 
                                                   queue: .main) { [spotifyService] notification in
                if let url = notification.object as? URL {
                    print("TrackyApp: Received Spotify callback URL from notification")
                    spotifyService.handleAuthCallback(url: url)
                }
            }
        }
        .onOpenURL { url in
            if url.scheme == "attentiontracker" {
                DispatchQueue.main.async {
                    self.spotifyService.handleAuthCallback(url: url)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
