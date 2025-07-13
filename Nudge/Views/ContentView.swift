import SwiftUI
import SwiftData
import AVFoundation
import AppKit


struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var coordinator = NudgeCoordinator()
    @State private var menuBarManager: MenuBarManager?
    
    var body: some View {
        ScrollView() {
            // Header
            VStack {
                Text("Nudge")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("AI-Powered Focus Assistant")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Status Section
            StatusCard(coordinator: coordinator)
            
            // Attention Metrics
            AttentionMetricsView(coordinator: coordinator)
            
            // Controls
            ControlsView(coordinator: coordinator)
            
            // Insights
            //InsightsView(coordinator: coordinator)
            
            //Camera Context
            //CameraContextView(coordinator: coordinator)
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 600)
        .onAppear {
            coordinator.modelContext = modelContext
            setupMenuBarIfNeeded()
        }
    }
    
    private func setupMenuBarIfNeeded() {
        guard menuBarManager == nil else { return }
        menuBarManager = MenuBarManager(coordinator: coordinator)
    }
}

struct StatusCard: View {
    @ObservedObject var coordinator: NudgeCoordinator
    @State private var cameraPermissionStatus: String = "Unknown"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                
                Text(coordinator.systemStatus.description)
                    .font(.headline)
                
                Spacer()
                
                if coordinator.isActive {
                    Text("ACTIVE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            // Camera permission status
            HStack {
                Image(systemName: "camera")
                    .foregroundColor(cameraStatusColor)
                Text("Camera: \(cameraPermissionStatus)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            if coordinator.isActive {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Attention Score")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(safePercentage(coordinator.currentAttentionScore))%")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Confidence")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(safePercentage(Double(coordinator.confidenceLevel)))%")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                }
                
                // Session Duration
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.blue)
                    Text("Session Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(coordinator.formattedSessionDuration)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .onAppear {
            updateCameraPermissionStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            updateCameraPermissionStatus()
        }
    }
    
    private var statusColor: Color {
        switch coordinator.systemStatus {
        case .active, .monitoring:
            return .green
        case .ready:
            return .blue
        case .paused:
            return .orange
        case .permissionRequired, .error:
            return .red
        default:
            return .gray
        }
    }
    
    private var cameraStatusColor: Color {
        switch cameraPermissionStatus {
        case "Authorized":
            return .green
        case "Denied", "Restricted":
            return .red
        case "Not Determined":
            return .orange
        default:
            return .gray
        }
    }
    
    private func updateCameraPermissionStatus() {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authStatus {
        case .authorized:
            cameraPermissionStatus = "Authorized"
        case .denied:
            cameraPermissionStatus = "Denied"
        case .restricted:
            cameraPermissionStatus = "Restricted"
        case .notDetermined:
            cameraPermissionStatus = "Not Determined"
        @unknown default:
            cameraPermissionStatus = "Unknown"
        }
    }
}

struct AttentionMetricsView: View {
    @ObservedObject var coordinator: NudgeCoordinator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Attention Metrics")
                .font(.headline)
            
            if coordinator.isActive {
                let metrics = coordinator.getAttentionMetrics()
                
                VStack(spacing: 8) {
                    
                    
                    MetricRow(label: "Face Detection", value: metrics.faceDetected ? "✓" : "✗")
                    MetricRow(label: "Eye Openness", value: "\(safePercentage(metrics.eyeOpenness))%")
                    MetricRow(label: "Gaze Direction", value: metrics.gazeDirection.capitalized)
                    MetricRow(label: "Active App", value: metrics.activeApplication)
                }
            } else {
                Text("Start monitoring to see metrics")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

struct CameraPreviewView: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer = previewLayer
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            self.previewLayer.frame = nsView.bounds
        }
    }
}

struct CameraContextView: View {
    @ObservedObject var coordinator: NudgeCoordinator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Camera Feed")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Camera feed as main focus
            if coordinator.isActive, let previewLayer = coordinator.attentionDetector.previewLayer {
                CameraPreviewView(previewLayer: previewLayer)
                    .frame(height: 200)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(coordinator.currentAttentionScore > 0.6 ? Color.green : Color.orange, lineWidth: 2)
                    )
            } else {
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .frame(height: 200)
                    .cornerRadius(8)
                    .overlay(
                        VStack {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("Camera feed unavailable")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    )
            }
            
            // Camera event details
            if coordinator.isActive {
                VStack(alignment: .leading, spacing: 8) {
                    // Face detection status
                    HStack {
                        Circle()
                            .fill(coordinator.currentAttentionScore > 0.6 ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text("Face Detection: \(coordinator.getAttentionMetrics().faceDetected ? "Active" : "Inactive")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Metrics row
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Attention")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%.0f", coordinator.currentAttentionScore * 100))%")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Eye Open")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%.0f", coordinator.getAttentionMetrics().eyeOpenness * 100))%")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Confidence")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%.0f", coordinator.confidenceLevel * 100))%")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                    }
                    
                    // Gaze direction
                    HStack {
                        Text("Gaze:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(coordinator.getAttentionMetrics().gazeDirection)
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    
                    // Active insights
                    if !coordinator.activeInsights.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Insights")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(coordinator.activeInsights, id: \.self) { insight in
                                Text("• \(insight)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } else {
                Text("Start monitoring to view camera events")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ControlsView: View {
    @ObservedObject var coordinator: NudgeCoordinator
    
    var body: some View {
        HStack(spacing: 20) {
            if coordinator.isActive {
                Button(action: {
                    coordinator.stopMonitoring()
                }) {
                    Label("Stop", systemImage: "stop.fill")
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Button(action: {
                    coordinator.startMonitoring()
                }) {
                    Label("Start Monitoring", systemImage: "play.fill")
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct InsightsView: View {
    @ObservedObject var coordinator: NudgeCoordinator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.headline)
            
            if coordinator.activeInsights.isEmpty {
                Text("No insights available yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(coordinator.activeInsights.prefix(3), id: \.self) { insight in
                    HStack {
                        Image(systemName: "lightbulb")
                            .foregroundColor(.yellow)
                        Text(insight)
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [AttentionState.self, ContextualData.self, BehavioralPattern.self])
}

// MARK: - Helper Functions

func safePercentage(_ value: Double) -> Int {
    // Ensure the value is finite and within reasonable bounds
    guard value.isFinite else { return 0 }
    
    let percentage = value * 100.0
    guard percentage.isFinite else { return 0 }
    
    // Clamp to 0-100 range and convert safely
    let clampedValue = max(0.0, min(percentage, 100.0))
    return Int(clampedValue.rounded())
}

func safePercentage(_ value: Float) -> Int {
    return safePercentage(Double(value))
}
