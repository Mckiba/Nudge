import SwiftUI
import SwiftData
import Combine

class MenuBarManager: ObservableObject {
    @Published var coordinator: NudgeCoordinator
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    
    @MainActor
    init(coordinator: NudgeCoordinator) {
        self.coordinator = coordinator
        setupMenuBar()
        setupObservers()
    }
    
    @MainActor private func setupObservers() {
        // Update menu bar icon when attention score, active state, or session duration changes
        coordinator.$currentAttentionScore
            .combineLatest(coordinator.$isActive, coordinator.$formattedSessionDuration)
            .sink { [weak self] _, _, _ in
                self?.updateMenuBarIcon()
            }
            .store(in: &cancellables)
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let statusButton = statusItem?.button {
            statusButton.action = #selector(statusBarButtonClicked)
            statusButton.target = self
            
            // Start with a default icon
            updateMenuBarIcon()
        }
    }
    
    @objc private func statusBarButtonClicked() {
        showPopover()
    }
    
    private func showPopover() {
        guard let statusButton = statusItem?.button else { return }
        
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 500)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPopoverView(coordinator: coordinator)
        )
        
        popover.show(relativeTo: statusButton.bounds, of: statusButton, preferredEdge: .minY)
    }
    
    func updateMenuBarIcon() {
        guard let statusButton = statusItem?.button else { return }
        
        DispatchQueue.main.async {
            let attentionScore = self.coordinator.currentAttentionScore
            let isActive = self.coordinator.isActive
            let sessionDuration = self.coordinator.formattedSessionDuration
            
            if !isActive {
                // Inactive state - gray circle
                statusButton.image = self.createStatusImage(color: .systemGray, symbol: "circle.fill")
                statusButton.toolTip = "Nudge - Inactive"
            } else if attentionScore > 0.7 {
                // High attention - green circle
                statusButton.image = self.createStatusImage(color: .systemGreen, symbol: "circle.fill")
                statusButton.toolTip = "Nudge - High Attention (\(Int(attentionScore * 100))%) - Session: \(sessionDuration)"
            } else if attentionScore > 0.4 {
                // Medium attention - orange circle
                statusButton.image = self.createStatusImage(color: .systemOrange, symbol: "circle.fill")
                statusButton.toolTip = "Nudge - Medium Attention (\(Int(attentionScore * 100))%) - Session: \(sessionDuration)"
            } else {
                // Low attention - red circle
                statusButton.image = self.createStatusImage(color: .systemRed, symbol: "circle.fill")
                statusButton.toolTip = "Nudge - Low Attention (\(Int(attentionScore * 100))%) - Session: \(sessionDuration)"
            }
        }
    }
    
    private func createStatusImage(color: NSColor, symbol: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        
        image?.isTemplate = false
        
        // Create colored version
        if let image = image {
            let coloredImage = NSImage(size: image.size)
            coloredImage.lockFocus()
            color.set()
            image.draw(at: .zero, from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1.0)
            coloredImage.unlockFocus()
            return coloredImage
        }
        
        return image
    }
}

struct MenuBarPopoverView: View {
    @ObservedObject var coordinator: NudgeCoordinator
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Nudge")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Quick status
            HStack {
                Circle()
                    .fill(coordinator.currentAttentionScore > 0.6 ? Color.green : Color.orange)
                    .frame(width: 12, height: 12)
                
                Text("Status: \(coordinator.systemStatus.description)")
                    .font(.subheadline)
                
                Spacer()
                
                if coordinator.isActive {
                    Text("\(Int(coordinator.currentAttentionScore * 100))%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal)
            
            // Session duration when active
            if coordinator.isActive {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("Session Duration: \(coordinator.formattedSessionDuration)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            // Camera Context View
            CameraContextView(coordinator: coordinator)
                .padding(.horizontal)
            
            // Controls
            HStack(spacing: 12) {
                if coordinator.isActive {
                    Button("Stop") {
                        coordinator.stopMonitoring()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else {
                    Button("Start") {
                        coordinator.startMonitoring()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 400, height: 500)
    }
}
