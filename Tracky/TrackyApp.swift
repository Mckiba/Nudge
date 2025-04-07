//
//  TrackyApp.swift
//  Tracky
//
//  Created by McKiba Williams on 7/9/24.
//

import SwiftUI
import AppKit

@main
struct AttentionTrackerApp: App {
    @StateObject private var activityManager = ActivityTrackingManager()
    @StateObject private var cameraManager = CameraTrackingManager()
    @StateObject private var spotifyService = SpotifyService(
        clientID: "18371473c3b9422abfb89542a6922e90",
        clientSecret: "8aa9a304e448466e8ab39830c68b9731"
    )
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    private var menuBarController: MenuBarController?
    
    init() {
           menuBarController = MenuBarController(activityManager: activityManager)
           activityManager.integrateCamera(cameraManager)
       }
    
    var body: some Scene {
        WindowGroup {
            DashboardView(
                activityManager: activityManager,
                cameraManager: cameraManager,
                spotifyService: spotifyService
            )
            .onAppear {

                activityManager.integrateCamera(cameraManager)
                
                // Setup Spotify service in the AppDelegate through multiple mechanisms
                appDelegate.spotifyService = spotifyService
                
//                // Static method
                AppDelegate.setupSpotifyService(spotifyService)
                
                // Direct access to app delegate
                if let appDelegateRef = NSApplication.shared.delegate as? AppDelegate {
                    print("TrackyApp: Found AppDelegate, setting spotifyService directly")
                    appDelegateRef.spotifyService = spotifyService
                } else {
                    print("TrackyApp: Failed to get AppDelegate!")
                }
                
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
            .frame(minWidth: 500, minHeight: 700)
            .onOpenURL { url in
                // Handle the URL directly here as a backup mechanism
                print("SwiftUI.onOpenURL received: \(url)")
                if url.scheme == "attentiontracker" {
                    print("SwiftUI: Processing URL with scheme: \(url.scheme ?? "nil")")
                    DispatchQueue.main.async {
                        self.spotifyService.handleAuthCallback(url: url)
                        // Activate app window
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    }
                } else {
                    print("SwiftUI: Received URL with unexpected scheme: \(url.scheme ?? "nil")")
                }
            }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

