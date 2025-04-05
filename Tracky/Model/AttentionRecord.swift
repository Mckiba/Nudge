//
//  AttentionRecord.swift
//  Tracky
//
//  Created by McKiba Williams on 4/5/25.
//

import SwiftUI
import Combine
import AppKit
import Foundation

// MARK: - Core Data Models

struct AttentionRecord {
    let timestamp: Date
    let state: AttentionState
    let duration: TimeInterval
    let activeApp: String?
}

enum AttentionState: String, CaseIterable {
    case inFocus = "In Focus"
    case lowFocus = "Low Focus"
    case distracted = "Distracted"
    case phoneInHand = "Phone in Hand"
    case awayFromScreen = "Away from Screen"
    case idle = "Idle"
    
    var icon: String {
        switch self {
        case .inFocus: return "🎯"
        case .lowFocus: return "🔍"
        case .distracted: return "🪁"
        case .phoneInHand: return "📱"
        case .awayFromScreen: return "🚪"
        case .idle: return "💤"
        }
    }
}
