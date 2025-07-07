//
//  NudgeApp.swift
//  Nudge
//
//  Created by McKiba Williams on 6/25/25.
//

import SwiftUI
import SwiftData

@main
struct NudgeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            AttentionState.self,
            ContextualData.self,
            BehavioralPattern.self
        ])
    }
}
