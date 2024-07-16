//
//  TrackyApp.swift
//  Tracky
//
//  Created by McKiba Williams on 7/9/24.
//

import SwiftUI

@main
struct TrackyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

extension NSTextField{
    open override var focusRingType: NSFocusRingType {
        get{return .none}
        set{}
    }
}
