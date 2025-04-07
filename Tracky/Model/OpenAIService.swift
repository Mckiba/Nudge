//
//  OpenAIService.swift
//  Tracky
//
//  Created by McKiba Williams on 4/5/25.
//
import SwiftUI
import Combine
import AppKit
import Foundation


// MARK: - OpenAI Integration Service
let environment = ProcessInfo.processInfo.environment


class OpenAIService {
    private let apiKey: String
    private let endpoint = "https://api.openai.com/v1/completions"
    
    init(apiKey: String) {
        self.apiKey = environment["openAI_key"]!

    }
    
    
        func analyzeAttentionPatterns(
            records: [AttentionRecord],
            currentState: AttentionState,
            musicActive: Bool,
            completion: @escaping (String) -> Void
        ) {
            // Convert records to a format suitable for OpenAI
            let recordsText = records.prefix(20).map { record in
                "Time: \(record.timestamp), State: \(record.state.rawValue), " +
                "Duration: \(Int(record.duration))s, App: \(record.activeApp ?? "Unknown")"
            }.joined(separator: "\n")
            
            // Calculate some basic statistics to enhance the analysis
            let stateDistribution = calculateStateDistribution(records: records)
            let avgFocusDuration = calculateAverageDuration(for: .inFocus, in: records)
            let avgDistractedDuration = calculateAverageDuration(for: .distracted, in: records)
            let contextSwitchRate = calculateContextSwitchRate(records: records)
            
            let prompt = """
            Analyze the following attention state records and provide insights:
            
            \(recordsText)
            
            Current state: \(currentState.rawValue)
            Music playing: \(musicActive ? "Yes" : "No")
            
            Statistics:
            - Time in focus: \(Int(stateDistribution[.inFocus] ?? 0))s
            - Time distracted: \(Int(stateDistribution[.distracted] ?? 0))s
            - Average focus duration: \(Int(avgFocusDuration))s
            - Average distraction duration: \(Int(avgDistractedDuration))s
            - Context switch rate: \(String(format: "%.2f", contextSwitchRate)) switches/minute
            
            Based on these patterns:
            1. What's one key observation about the user's focus habits?
            2. Give one specific, actionable recommendation to improve productivity
            3. Suggest whether music would help their current state and what type (calm, upbeat, etc.)
            
            Keep your response concise and actionable.
            """
            
            // For the MVP, let's use a mock response to avoid requiring an actual OpenAI API key
            // In production, you would make the actual API call as shown below
            
            // Simulate network delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let mockResponse = self.generateMockResponse(
                    currentState: currentState,
                    musicActive: musicActive,
                    focusTime: stateDistribution[.inFocus] ?? 0,
                    distractedTime: stateDistribution[.distracted] ?? 0
                )
                
                completion(mockResponse)
            }
            
            /* Actual OpenAI API implementation (uncomment for production)
            guard let url = URL(string: endpoint) else {
                completion("Unable to analyze attention patterns at this time.")
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let requestBody: [String: Any] = [
                "model": "gpt-4-turbo",
                "messages": [
                    ["role": "system", "content": "You are a productivity assistant that analyzes attention patterns."],
                    ["role": "user", "content": prompt]
                ],
                "max_tokens": 150
            ]
            
            request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("OpenAI API error: \(error)")
                    DispatchQueue.main.async {
                        completion("Unable to analyze patterns: Network error")
                    }
                    return
                }
                
                guard let data = data else {
                    DispatchQueue.main.async {
                        completion("No data received from OpenAI")
                    }
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        
                        DispatchQueue.main.async {
                            completion(content)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion("Unable to parse OpenAI response")
                        }
                    }
                } catch {
                    print("JSON parsing error: \(error)")
                    DispatchQueue.main.async {
                        completion("Error processing the analysis")
                    }
                }
            }.resume()
            */
        }
        
        // MARK: - Helper Methods for Analysis
        
        private func calculateStateDistribution(records: [AttentionRecord]) -> [AttentionState: TimeInterval] {
            var distribution: [AttentionState: TimeInterval] = [:]
            
            for record in records {
                distribution[record.state, default: 0] += record.duration
            }
            
            return distribution
        }
        
        private func calculateAverageDuration(for state: AttentionState, in records: [AttentionRecord]) -> TimeInterval {
            let stateRecords = records.filter { $0.state == state }
            guard !stateRecords.isEmpty else { return 0 }
            
            let totalDuration = stateRecords.reduce(0) { $0 + $1.duration }
            return totalDuration / Double(stateRecords.count)
        }
        
        private func calculateContextSwitchRate(records: [AttentionRecord]) -> Double {
            guard records.count > 1 else { return 0 }
            
            // Count state changes
            var stateChanges = 0
            for i in 1..<records.count {
                if records[i].state != records[i-1].state {
                    stateChanges += 1
                }
            }
            
            // Calculate total time in minutes
            let firstTimestamp = records.first!.timestamp
            let lastTimestamp = records.last!.timestamp.addingTimeInterval(records.last!.duration)
            let totalMinutes = lastTimestamp.timeIntervalSince(firstTimestamp) / 60
            
            // Avoid division by zero
            guard totalMinutes > 0 else { return 0 }
            
            return Double(stateChanges) / totalMinutes
        }
        
        // MARK: - Mock Response Generator
        
        private func generateMockResponse(
            currentState: AttentionState,
            musicActive: Bool,
            focusTime: TimeInterval,
            distractedTime: TimeInterval
        ) -> String {
            // Simple logic to generate different responses based on the current state
            switch currentState {
            case .inFocus:
                if musicActive {
                    return "You're maintaining good focus periods with music playing. Consider extending your focus sessions by 5 minutes before taking breaks to build focus endurance. Your current music selection seems to be working well - instrumental tracks appear to complement your focused work."
                } else {
                    return "You're showing strong focus patterns, averaging 25-30 minute periods of deep work. Consider trying ambient or classical music to potentially enhance your concentration during complex tasks."
                }
                
            case .lowFocus:
                return "I notice you're frequently switching between applications, which may be fragmenting your attention. Try the Pomodoro technique (25 minutes of focus, 5 minute break) to build momentum. Instrumental music with a steady rhythm could help maintain a more consistent workflow."
                
            case .distracted:
                if distractedTime > focusTime {
                    return "You're spending more time in distracted states than focused work. Try removing digital distractions by using Focus mode on your device. Upbeat, energizing music might help you reset and regain motivation to return to your primary tasks."
                } else {
                    return "Your current distraction appears temporary based on your patterns. When ready to refocus, consider a short break followed by a clear task objective. Low-fi or ambient soundtracks could help create a transition back to focused work."
                }
                
            case .phoneInHand:
                return "Phone usage is interrupting your workflow regularly. Consider setting designated times for checking your phone or using a phone-stacking method. If you need your phone for calls, upbeat music without lyrics could help minimize the temptation to check other apps."
                
            case .awayFromScreen:
                return "You've been away from your computer. This might be a good opportunity to plan your next focus session. When you return, consider starting with a 10-minute focused sprint before checking emails or messages. Calming music can help ease back into work mode."
                
            case .idle:
                return "You appear to be at your computer but not actively engaged. This might indicate decision fatigue or task uncertainty. Try breaking down your next objective into smaller steps. Rhythmic, medium-tempo music could help re-establish a productive cadence."
            }
        }
    }
