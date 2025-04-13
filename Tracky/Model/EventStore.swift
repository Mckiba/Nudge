//
//  EventStore.swift
//  Tracky
//
//  Created by McKiba Williams on 4/9/25.
//

import AppKit
import SwiftUI
import EventKit


struct EventDataStore {
    
    let eventStore: EKEventStore = EKEventStore()
    
    let calendar = Calendar.current
    
    func fetchEvents(for date: Date) -> [EKEvent] {
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        return eventStore.events(matching: predicate)
    }
    
    func fetchEvents(forMonth date: Date) -> [EKEvent] {
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else {
            return []
        }
        
        guard let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return []
        }

        let predicate = eventStore.predicateForEvents(withStart: startOfMonth, end: startOfNextMonth, calendars: nil)
        return eventStore.events(matching: predicate)
    }
    
    func hasEvents(on date: Date) -> Bool {
        let events = fetchEvents(for: date)
        return !events.isEmpty
    }
    
    func verifyAuthorizationStatus() async throws -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .notDetermined {
            return try await eventStore.requestFullAccessToEvents()
        }
        return true }
}
