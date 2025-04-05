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
    
    let activityManager = ActivityTrackingManager()
    let cameraManager = CameraTrackingManager()
    let menuBarController: MenuBarController
    
    init() {
        menuBarController = MenuBarController(activityManager: activityManager)
        // Integrate camera tracking with activity tracking
        activityManager.integrateCamera(cameraManager)
    }

    
    var body: some Scene {
        WindowGroup {
                    DashboardView(
                        activityManager: activityManager,
                        cameraManager: cameraManager
                    )
                }
    }
}
