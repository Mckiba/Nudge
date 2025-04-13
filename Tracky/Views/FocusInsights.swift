//
//  FocusInsights.swift
//  Tracky
//
//  Created by McKiba Williams on 4/13/25.
//

import SwiftUI
import Swift

struct FocusInsights: View {
    
    @ObservedObject var activityManager: ActivityTrackingManager
    @ObservedObject var spotifyService: SpotifyService
    @State private var insights: String = "Collecting data to generate insights..."


    var body: some View {
        // AI Insights section
        VStack(alignment: .leading) {
            HStack {
                Text("AI Insights")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    // Request new insights
                    let service = OpenAIService()
                    service.analyzeAttentionPatterns(
                        records: activityManager.attentionHistory,
                        currentState: activityManager.currentState,
                        musicActive: spotifyService.isPlaying
                    ) { result in
                        self.insights = result
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Refresh insights")
            }
            
            Text(insights)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
        }                    .padding()
    }
    
    
}
