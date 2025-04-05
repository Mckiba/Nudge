//
//  MenuBarController.swift
//  Tracky
//
//  Created by McKiba Williams on 4/5/25.
//

import Foundation
import Combine
import AppKit

class MenuBarController {
    private var statusItem: NSStatusItem?
    private var activityManager: ActivityTrackingManager
    
    init(activityManager: ActivityTrackingManager) {
        self.activityManager = activityManager
        
        // Delay setup to ensure it happens after the app is running
        DispatchQueue.main.async {
            self.setupMenuBar()
        }
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name("AttentionStateChanged"),
            object: nil,
            queue: .main) { [weak self] notification in
                self?.updateMenuBar()
            }
    }
    
    private func setupMenuBar() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMenuBar()
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Dashboard", action: #selector(showDashboard), keyEquivalent: "d"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    private func updateMenuBar() {
        // Check if statusItem is initialized before updating
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let button = self.statusItem?.button else { return }
            button.title = "\(self.activityManager.currentState.icon) \(self.activityManager.currentState.rawValue)"
        }
    }
    
    @objc private func showDashboard() {
        // Code to show main app window
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
