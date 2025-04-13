//
//  RecommendedPlaylistRow.swift
//  Tracky
//
//  Created by McKiba Williams on 4/13/25.
//

import SwiftUI

struct RecommendedPlaylistRow: View {
    let playlist: SpotifyPlaylist
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                // Playlist image placeholder (can be replaced with actual image)
                AsyncImage(url: URL(string: playlist.images[0].url)) {image
                    in image.resizable()
                }
                
                placeholder: {
                    
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "music.note")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(playlist.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(playlist.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.1)))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
