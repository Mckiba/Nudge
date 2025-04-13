//
//  Menubar.swift
//  Tracky
//
//  Created by McKiba Williams on 4/13/25.
//

import SwiftUI

struct MenuBar: View {
    
    var activityManager: ActivityTrackingManager
        var cameraManager: CameraTrackingManager
        
        var body: some View {
            HStack(spacing: 16) {
                NavigationLink(destination: SettingsView(activityManager: activityManager, cameraManager: cameraManager)) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15))
                        .foregroundColor(Color.black.opacity(0.7))
                }
                .buttonStyle(CircleButtonStyle())
                
                Button(action: {}) {
                    Image(systemName: "bell")
                        .font(.system(size: 15))
                        .foregroundColor(Color.black.opacity(0.7))
                }
                .buttonStyle(CircleButtonStyle())
                
                Button(action: {}) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 15))
                        .foregroundColor(Color.black.opacity(0.7))
                }
                .buttonStyle(CircleButtonStyle())
            }
        }
    
}

// Custom button style for right side icons
struct CircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(10)
            .background(Color.white)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(), value: configuration.isPressed)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// Preview
struct MenuBar_Previews: PreviewProvider {
    static var previews: some View {
        MenuBar(activityManager: ActivityTrackingManager(), cameraManager: CameraTrackingManager())
            .previewLayout(.sizeThatFits)
    }
}
