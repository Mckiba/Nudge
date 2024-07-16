//
//  CameraView.swift
//  Tracky
//
//  Created by McKiba Williams on 7/14/24.
//

import SwiftUI
import AVFoundation

import SwiftUI
import AVFoundation

struct CameraView: View {
    @ObservedObject var activityVM: ActivityController
    
    var body: some View {
        VStack {
            if let previewLayer = activityVM.previewLayer {
                CameraPreview(previewLayer: previewLayer)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("No Camera Preview Available")
                    .foregroundColor(.white)
            }
        }
        .background(Color.black)
    }
}

struct CameraPreview: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        previewLayer.frame = view.bounds
        view.layer = previewLayer
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

//
//#Preview {
//    CameraPreview()
//}
