//
//  EventStoreManager.swift
//  Tracky
//
//  Created by McKiba Williams on 4/9/25.
//

import AppKit
import SwiftUI
import EventKit


class EventStoreManager: ObservableObject {
    @Published var events: [EKEvent]
    @Published var selectedDateEvents: [EKEvent]
    let dataStore: EventDataStore
    
    init(store: EventDataStore = EventDataStore()) {
        self.dataStore = store
        self.events = []
        self.selectedDateEvents = []
    }
    
    func setupEventStore(date: Date) async throws {
        let response = try await dataStore.verifyAuthorizationStatus()
        if response {
            let monthlyEvents = dataStore.fetchEvents(forMonth: date)
            self.events = monthlyEvents
            print(events.first)
            updateSelectedDateEvents(for: date)
        }
    }
    
    func updateSelectedDateEvents(for date: Date) {
        self.selectedDateEvents = dataStore.fetchEvents(for: date)
    }
    
    func hasEvents(on date: Date) -> Bool {
        return events.contains { event in
            Calendar.current.isDate(event.startDate, inSameDayAs: date)
        }
    }
}

