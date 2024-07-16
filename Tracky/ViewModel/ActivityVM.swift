//
//  ActivityVM.swift
//  Tracky
//
//  Created by McKiba Williams on 7/14/24.
//


import Foundation
import Cocoa
import AVFoundation

class ActivityController: NSViewController, AVCaptureFileOutputRecordingDelegate, ObservableObject {
    var screenSession = AVCaptureSession()
    var cameraSession = AVCaptureSession()
    var input = AVCaptureScreenInput()
    var output = AVCaptureMovieFileOutput()
    var screenCaptureOutputUrl: URL? = nil
    var cameraOutputUrl: URL? = nil
    var isRecording = false
    var shouldRecordScreen: Bool = true
    var shouldRecordWebcam: Bool = true
    var shouldRecordMicrophone: Bool = true
    var screenCaptureURL: URL? = nil
    var shouldCaptureHealthData: Bool = true
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    @Published var showCameraView: Bool = false
    
    weak var previewView: NSView? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    private func createTempFileURL() -> URL {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last
        let pathURL = NSURL.fileURL(withPath: path!)
        let fileURL = pathURL.appendingPathComponent("rec-\(NSDate.timeIntervalSinceReferenceDate).mov")
        return fileURL
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        output.stopRecording()
    }
    
    func startStopCaptureButtonPressed() {
        print("Clicked")
        if !isRecording {
            isRecording = true
            showCameraView = true
            print(showCameraView)
            print("Running")
            if shouldRecordScreen {
                screenSession = AVCaptureSession.init()
                screenSession.beginConfiguration()
                screenSession.sessionPreset = .high
                input = AVCaptureScreenInput(displayID: CGMainDisplayID())!
                screenSession.addInput(input)
                output = AVCaptureMovieFileOutput()
                screenSession.addOutput(self.output)
                screenSession.commitConfiguration()
                screenSession.startRunning()
                screenCaptureURL = createTempFileURL()
                output.startRecording(to: screenCaptureURL!, recordingDelegate: self)
            }
            if (shouldRecordWebcam || shouldRecordMicrophone) {
                cameraSession = AVCaptureSession.init()
                cameraSession.beginConfiguration()
                cameraSession.sessionPreset = .high
                if shouldRecordWebcam {
                    let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified)
                    guard
                        let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice!),
                        cameraSession.canAddInput(videoDeviceInput)
                    else { return }
                    cameraSession.addInput(videoDeviceInput)
                    previewLayer = AVCaptureVideoPreviewLayer(session: cameraSession)
                    previewLayer!.videoGravity = .resizeAspectFill
                    DispatchQueue.main.async {
                        if let previewView = self.previewView {
                            self.previewLayer!.frame = previewView.bounds
                            previewView.layer?.addSublayer(self.previewLayer!)
                        }
                    }
                }
                if shouldRecordMicrophone {
                    let audioDevice = AVCaptureDevice.default(.microphone, for: .audio, position: .unspecified)
                    guard
                        let audioDeviceInput = try? AVCaptureDeviceInput(device: audioDevice!),
                        cameraSession.canAddInput(audioDeviceInput)
                    else { return }
                    cameraSession.addInput(audioDeviceInput)
                }
                output = AVCaptureMovieFileOutput()
                cameraSession.addOutput(self.output)
                cameraSession.commitConfiguration()
                cameraSession.startRunning()
                cameraOutputUrl = createTempFileURL()
                output.startRecording(to: cameraOutputUrl!, recordingDelegate: self)
            }
        } else {
            isRecording = false
            showCameraView = false
            if self.cameraSession.isRunning {
                self.cameraSession.stopRunning()
            }
            if self.screenSession.isRunning {
                self.screenSession.stopRunning()
            }
        }
    }
    
    func showInFinder(url: URL?) {
        NSWorkspace.shared.selectFile(url?.relativePath, inFileViewerRootedAtPath: "")
    }
}
