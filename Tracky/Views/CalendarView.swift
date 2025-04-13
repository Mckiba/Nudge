//
//  CalendarView.swift
//  Tracky
//
//  Created by McKiba Williams on 4/11/25.
//

import SwiftUI

struct MonthlyCalendarView: View {
    @ObservedObject var eventStoreManager = EventStoreManager()
    @Binding var selectedDate: Date
    @State private var currentMonth = Date()
    
    private let calendar = Calendar.current
    private let daysInWeek = 7
    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 10) {
            // Month navigation header
            HStack {
                Button(action: { moveMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text(monthFormatter.string(from: currentMonth))
                    .font(.headline)
                
                Spacer()
                
                Button(action: { moveMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            // Day of week headers
            HStack(spacing: 0) {
                ForEach(getDaysOfWeek(), id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar days grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: daysInWeek), spacing: 8) {
                ForEach(getDaysInMonth(), id: \.self) { date in
                    if let date = date {
                        DayView(
                            date: date,
                            hasEvents: hasEvents(on: date),
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                    } else {
                        // Empty placeholder for days that don't exist in this month
                        Rectangle()
                            .foregroundColor(.clear)
                            .frame(height: 40)
                    }
                }
            }
        }
        .padding()
//        .background(Color(.gray))
        .cornerRadius(8)
    }
    
    private func moveMonth(by amount: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: amount, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    private func getDaysOfWeek() -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return (0..<daysInWeek).map { idx in
            let index = (idx + calendar.firstWeekday - 1) % daysInWeek
            return formatter.shortWeekdaySymbols[index]
        }
    }
    
    private func getDaysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end - 1) else {
            return []
        }
        
        let firstDay = monthFirstWeek.start
        let lastDay = monthLastWeek.end
        
        var allDays = [Date?]()
        var currentDay = firstDay
        
        // Add days from the first day of the first week to the last day of the last week
        while currentDay < lastDay {
            allDays.append(currentDay)
            currentDay = calendar.date(byAdding: .day, value: 1, to: currentDay)!
        }
        
        return allDays
    }
    
    private func hasEvents(on date: Date) -> Bool {
        return eventStoreManager.events.contains { event in
            calendar.isDate(event.startDate, inSameDayAs: date)
        }
    }
}

struct DayView: View {
    let date: Date
    let hasEvents: Bool
    let isSelected: Bool
    let isCurrentMonth: Bool
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 14))
                .foregroundColor(textColor)
        }
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .background(background)
        .cornerRadius(6)
    }
    
    private var textColor: Color {
        if !isCurrentMonth {
            return Color.gray.opacity(0.5)
        } else if calendar.isDateInToday(date) {
            return Color.white
        } else {
            return Color.primary
        }
    }
    
    private var background: some View {
        Group {
            if calendar.isDateInToday(date) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 28, height: 28)
            } else if isSelected {
                Circle()
                    .fill(Color.pink)
                    .frame(width: 28, height: 28)
            } else if hasEvents {
                Circle()
                    .fill(Color.red)
                    .frame(width: 28, height: 28)
            } else {
                Color.clear
            }
        }
    }
}

struct MonthlyCalendarView_Previews: PreviewProvider {
    static var previews: some View {
        PreviewWrapper()
    }
    
    struct PreviewWrapper: View {
        @State private var selectedDate = Date()
        
        var body: some View {
            
            HStack {
                MonthlyCalendarView(selectedDate: $selectedDate)
                    .frame(width: 300, height: 400)
                    .padding()
                
                CalendarEvents(selectedDate: selectedDate)
            }

        }
    }
}

