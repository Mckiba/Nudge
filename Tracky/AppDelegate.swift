//
//  AppDelegate.swift
//  Tracky
//
//  Created by McKiba Williams on 4/5/25.
//

import AppKit
import SwiftUI


class AppDelegate: NSObject, NSApplicationDelegate {
    var spotifyService: SpotifyService?
    
    // Use lazy initialization for shared to avoid initialization cycles
    private static var _shared: AppDelegate?
    static var shared: AppDelegate {
        if let existing = _shared {
            return existing
        }
        let newInstance = AppDelegate()
        _shared = newInstance
        return newInstance
    }
    
    // Workaround to get access to the SpotifyService from anywhere
    static func setupSpotifyService(_ service: SpotifyService) {
        print("AppDelegate.setupSpotifyService: Setting service")
        Self.shared.spotifyService = service
        (NSApplication.shared.delegate as? AppDelegate)?.spotifyService = service
    }
    
    override init() {
        super.init()
        // Capture this instance as the shared one if not already set
        if AppDelegate._shared == nil {
            AppDelegate._shared = self
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("AppDelegate: Application did finish launching")
        
        // Register to handle URL scheme
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        print("AppDelegate: Registered URL scheme handler")
        
        // For debugging - log if spotifyService is available
        if spotifyService != nil {
            print("AppDelegate: spotifyService is available at launch")
        } else {
            print("AppDelegate: WARNING - spotifyService is nil at launch!")
        }
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        print("AppDelegate: application(_:open:) called with URLs: \(urls)")
        
        guard let url = urls.first, url.scheme == "attentiontracker" else {
            print("AppDelegate: URL scheme is not attentiontracker or no URL")
            return
        }
        
        // Handle Spotify callback
        handleCallbackUrl(url)
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        print("AppDelegate: Application will finish launching")
        
        // Register to handle URL scheme
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }
    
    // Helper method to handle URL callback with different ways to get spotifyService
    private func handleCallbackUrl(_ url: URL) {
        print("AppDelegate: Handling callback URL: \(url)")
        
        // Try multiple ways to get spotifyService
        if let spotifyService = self.spotifyService {
            print("AppDelegate: Using instance spotifyService")
            spotifyService.handleAuthCallback(url: url)
        } else if let spotifyService = AppDelegate.shared.spotifyService {
            print("AppDelegate: Using shared spotifyService")
            spotifyService.handleAuthCallback(url: url)
        } else {
            print("AppDelegate: ERROR - spotifyService is nil! Trying notification")
            
            // Also try the static method as another fallback
            print("AppDelegate: Trying static handler")
            SpotifyService.handleCallbackUrlStatic(url)
            
            // Broadcast notification as last resort
            DispatchQueue.main.async {
                print("AppDelegate: Broadcasting URL notification")
                NotificationCenter.default.post(name: NSNotification.Name("SpotifyCallbackURL"), object: url)
            }
        }
        
        // Activate the app to bring it to the foreground
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        print("AppDelegate: handleURLEvent called with event: \(event)")
        
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue else {
            print("AppDelegate: Could not extract URL string from event")
            return
        }
        guard let url = URL(string: urlString) else {
            print("AppDelegate: Could not create URL from string")
            return
        }
        guard url.scheme == "attentiontracker" else {
            print("AppDelegate: URL scheme is not attentiontracker: \(url.scheme ?? "nil")")
            return
        }
        
        // Handle the URL using our helper method
        handleCallbackUrl(url)
    }
}

