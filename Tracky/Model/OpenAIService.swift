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
    
    func analyzeAttentionPatterns(records: [AttentionRecord], completion: @escaping (String) -> Void) {
        // Convert records to a format suitable for OpenAI
        let recordsText = records.map { record in
            "Time: \(record.timestamp), State: \(record.state.rawValue), " +
            "Duration: \(Int(record.duration))s, App: \(record.activeApp ?? "Unknown")"
        }.joined(separator: "\n")
        
        let prompt = """
        Analyze the following attention state records and provide insights:
        
        \(recordsText)
        
        Based on these patterns, what are 1-2 key observations about the user's focus habits?
        """
        
        // Make API call to OpenAI (simplified implementation)
        // In real implementation, use proper URLSession and error handling
        print("Would send to OpenAI: \(prompt)")
        
        // Mock response for MVP
        let mockResponse = "I notice you tend to get distracted after 45 minutes of focus work. " +
                           "Consider taking intentional breaks to maintain longer focus periods."
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(mockResponse)
        }
    }
}

