//
//  SwiftUIView.swift
//  Tracky
//
//  Created by McKiba Williams on 7/13/24.
//


import SwiftUI

struct CreateActivity: View {
    @ObservedObject var activityVM: ActivityController
    
    @State private var activityName: String = ""
    @State private var activityDuration: String = ""
    @State private var activityType: String = ""
    @State private var workspace: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            Text("Create Activity")
                .font(Font.custom("Inter", size: 20).weight(.regular))
                .foregroundColor(.white)
            
            HStack(alignment: .top, spacing: 80) {
                VStack {
                    TextField("Activity Name", text: $activityName)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .frame(width: 475, height: 44, alignment: .leading)
                        .background(Color.black)
                        .clipShape(Capsule())
                    
                    TextField("Duration", text: $activityDuration)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .frame(width: 475, height: 44, alignment: .leading)
                        .background(Color.black)
                        .clipShape(Capsule())
                    
                    TextField("Activity Type", text: $activityType)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .frame(width: 475, height: 44, alignment: .leading)
                        .background(Color.black)
                        .clipShape(Capsule())
                    
                    TextField("Create/Load Workspace", text: $workspace)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .frame(width: 475, height: 44, alignment: .leading)
                        .background(Color.black)
                        .clipShape(Capsule())
                    
                    Button("Start Activity") {
                        activityVM.startStopCaptureButtonPressed()
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .padding(.top, 40)
                }
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("Monitoring")
                        .font(Font.custom("Inter", size: 20).weight(.regular))
                        .foregroundColor(.white)
                    
                    Toggle("Web Cam", isOn: $activityVM.shouldRecordWebcam)
                        .foregroundColor(.white)
                    
                    Toggle("Microphone", isOn: $activityVM.shouldRecordMicrophone)
                        .foregroundColor(.white)
                    
                    Toggle("Screen", isOn: $activityVM.shouldRecordScreen)
                        .foregroundColor(.white)
                    
                    Toggle("Health Data", isOn: $activityVM.shouldCaptureHealthData)
                        .foregroundColor(.white)
                }
            }
        }
        .foregroundColor(.clear)
        .frame(width: 885, height: 808)
        .background(Color(red: 0.13, green: 0.13, blue: 0.18))
        .cornerRadius(32)
    }
}

#Preview {
    HomeView()
}
