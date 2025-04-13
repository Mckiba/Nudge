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
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    private var menuBarController: MenuBarController?
    
    init() {
        menuBarController = MenuBarController(activityManager: ActivityTrackingManager())
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 500, minHeight: 700)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

