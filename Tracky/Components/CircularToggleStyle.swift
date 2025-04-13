//
//  CircularToggleStyle.swift
//  Tracky
//
//  Created by McKiba Williams on 4/13/25.
//


import SwiftUI

struct CircularCheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            HStack {
                ZStack {
                    Circle()
                        .fill(configuration.isOn ?
                              Color.orange : Color.black)
//                     /*   .stroke(configuration.isOn ? Color.orange : Color.orange,*/ lineWidth: 2)
                        .frame(width: 20, height: 20)
                    

                    if configuration.isOn {
                        Image(systemName: "checkmark"
                        ).foregroundStyle(Color.black)

                    }
                }

                configuration.label
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

