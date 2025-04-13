//
//  CalendarEvents.swift
//  Tracky
//
//  Created by McKiba Williams on 4/9/25.
//

import EventKit
import SwiftUI

struct CalendarEvents: View {
    @StateObject private var storeManager = EventStoreManager()
    @State private var vibrateOnRing = true
    

    
    
    
    
    

    let selectedDate: Date
    
    var body: some View {

        VStack {
            List {
                ForEach(storeManager.selectedDateEvents, id: \.self) { event in
                    HStack {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(event.title)
                                .font(.subheadline)
                            Text(event.startDate.formatted())
                                .font(.caption)
                        }
                        Spacer()
                        
                        Toggle("", isOn: $vibrateOnRing)
                                   .toggleStyle(CircularCheckboxToggleStyle())
                                   .padding()

                    


//                        Toggle(isOn: true)
//                            .toggleStyle(.checkbox)
//                            .frame(width: 20, height: 20)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
            .task {
                do {
                    try await storeManager.setupEventStore(date: selectedDate)
                } catch {
                    print("Authorization failed. \(error)")
                }
            }
            .onChange(of: selectedDate) { newDate in
                storeManager.updateSelectedDateEvents(for: newDate)
            }
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
        .frame(minWidth: 200, maxWidth: 250, minHeight: 400, maxHeight: 450)
    }
}

#Preview {
    CalendarEvents(selectedDate: Date())
}


