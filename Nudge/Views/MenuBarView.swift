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
        // Update menu bar icon when attention display, session duration, or active state changes
        coordinator.$attentionScoreDisplay
            .combineLatest(coordinator.$formattedSessionDuration, coordinator.$isActive)
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
            
            // Enable layer-backed views for background coloring
            statusButton.wantsLayer = true
            
            // Start with a default icon
            updateMenuBarIcon()
        }
    }
    
    @objc private func statusBarButtonClicked() {showPopover()}
    
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
            let attentionDisplay = self.coordinator.attentionScoreDisplay
            let sessionDuration = self.coordinator.formattedSessionDuration
            let isActive = self.coordinator.isActive
            statusButton.image = nil
            
            // Determine color based on attention display
            let color: NSColor
            switch attentionDisplay {
            case "High Attention":
                color = .systemGreen
            case "Medium Attention":
                color = .systemOrange
            case "Low Attention":
                color = .systemRed
            default: // "Inactive"
                color = .systemGray
            }
            // Set the display text and tooltip
            let duration = isActive ? sessionDuration : "00:00"
            statusButton.attributedTitle = self.createAttributedTitle(
                text: attentionDisplay,
                duration: duration,
                color: color
            )
            
            // Set the button's background color
            statusButton.layer?.backgroundColor = color.cgColor
            statusButton.layer?.cornerRadius = 4
            
            // Create tooltip with percentage if active
            if isActive {
                let percentage = Int(self.coordinator.currentAttentionScore * 100)
                statusButton.toolTip = "Nudge - \(attentionDisplay) (\(percentage)%)"
            } else {
                statusButton.toolTip = "Nudge - \(attentionDisplay)"
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
    
    private func createAttributedTitle(text: String, duration: String, color: NSColor) -> NSAttributedString {
        let dotText = "●"
        let fullText = dotText + " " + text + " " + duration
        
        let attributedString = NSMutableAttributedString(string: fullText)

        // Set white text color for good contrast
        attributedString.addAttribute(.foregroundColor, value: NSColor.white, range: NSRange(location: 0, length: fullText.count))
        
        return attributedString
    }
}

struct MenuBarPopoverView: View {
    @ObservedObject var coordinator: NudgeCoordinator
    
    var body: some View {
        VStack(spacing: 16) {
            if coordinator.isActive {
                HStack(alignment: .center) {
                    Text(coordinator.formattedSessionDuration)
                        .font(
                            Font.custom("Inter", size: 30)
                                .weight(.semibold)
                        )
                        .foregroundColor(Color(red: 0.93, green: 0.58, blue: 0.05))
                    
                    Spacer()
                    
                    VStack(alignment: .leading){
                        Text(coordinator.attentionScoreDisplay)
                            .font(
                                Font.custom("Inter", size: 20)
                                    .weight(.semibold)
                            )
                            .fixedSize(horizontal: true, vertical: true)
                            .foregroundColor(Color(red: 0.91, green: 0.57, blue: 0.06))
                           
                        
                        Text("\(Int(coordinator.confidenceLevel * 100))% confidence")
                            .font(Font.custom("Inter", size: 20))
                            .foregroundColor(Color(red: 0.47, green: 0.47, blue: 0.48))
                            .frame(width: 156, height: 22, alignment: .leading)
                    }
                }
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            
            Rectangle()
                .padding(.horizontal)
              .foregroundColor(.clear)
              .frame(maxWidth: .infinity, minHeight: 2, maxHeight: 2)
              .background(Color(red: 0.85, green: 0.85, blue: 0.85).opacity(0.2))
            
            
            if (coordinator.isActive){
                HStack{
                    VStack{
                        
                        Text("\(Int(coordinator.currentAttentionScore * 100))%")
                            .font(Font.custom("SF Pro", size: 28)
                                .weight(.semibold)
                            )
                            .foregroundColor(Color(red: 0.94, green: 0.27, blue: 0.22))
                        
                        Text("ATTENTION SCORE")
                            .font(Font.custom("SF Pro", size: 15))
                            .foregroundColor(Color(red: 0.48, green: 0.48, blue: 0.49))
                        
                        Text("-12% from weekly avg")
                            .font(Font.custom("SF Pro", size: 14))
                            .foregroundColor(Color(red: 0.77, green: 0.24, blue: 0.21))
                        
                    }
                    .foregroundColor(.clear)
                    .frame(width: 160.59999, height: 99)
                    .background(Color(red: 0.16, green: 0.16, blue: 0.16))
                    .cornerRadius(13)
                    .overlay(
                        RoundedRectangle(cornerRadius: 13)
                            .inset(by: 0.5)
                            .stroke(Color(red: 0.37, green: 0.37, blue: 0.38), lineWidth: 1)
                    )
                    
                    
                    VStack{
                        
                        Text("7").font(Font.custom("SF Pro", size: 28)
                                    .weight(.semibold)
                            )
                            .foregroundColor(Color(red: 0.97, green: 0.6, blue: 0.05))
                        
                        Text("DISTRACTIONS")
                            .font(Font.custom("SF Pro", size: 15))
                            .foregroundColor(Color(red: 0.48, green: 0.48, blue: 0.49))
                        
                        Text("+3 from avg")
                            .font(Font.custom("SF Pro", size: 14))
                            .foregroundColor(Color(red: 0.19, green: 0.67, blue: 0.3))
                        
                    }
                    .foregroundColor(.clear)
                    .frame(width: 160.59999, height: 99)
                    .background(Color(red: 0.16, green: 0.16, blue: 0.16))
                    .cornerRadius(13)
                    .overlay(
                        RoundedRectangle(cornerRadius: 13)
                            .inset(by: 0.5)
                            .stroke(Color(red: 0.37, green: 0.37, blue: 0.38), lineWidth: 1)
                    )
                }
            }
        
            if coordinator.isActive {
                    Text("Data Sources")
                      .font(Font.custom("SF Pro", size: 14))
                      .foregroundColor(.white)
                      .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack{
                    Text("Visual Tracking")
                        .font(Font.custom("Inter", size: 12))
                        .foregroundColor(Color(red: 0.18, green: 0.7, blue: 0.31))
                        .foregroundColor(.clear)
                        .frame(width: 146, height: 24)
                        .background(Color(red: 0.15, green: 0.25, blue: 0.16))
                        .cornerRadius(19)
                        .overlay(
                            RoundedRectangle(cornerRadius: 19)
                                .inset(by: 0.5)
                                .stroke(Color(red: 0.18, green: 0.7, blue: 0.31), lineWidth: 1)
                        )
                    
                    Text("Screen Tracking")
                        .font(Font.custom("Inter", size: 12))
                        .foregroundColor(Color(red: 0.18, green: 0.7, blue: 0.31))
                        .foregroundColor(.clear)
                        .frame(width: 146, height: 24)
                        .background(Color(red: 0.15, green: 0.25, blue: 0.16))
                        .cornerRadius(19)
                        .overlay(
                            RoundedRectangle(cornerRadius: 19)
                                .inset(by: 0.5)
                                .stroke(Color(red: 0.18, green: 0.7, blue: 0.31), lineWidth: 1)
                        )
                }
                
            }

            // MARK: -   Camera Context View
            CameraContextView(coordinator: coordinator)
            
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
        .padding(.horizontal, 15)
        .padding(.vertical, 20)
        .frame(width: 400, alignment: .center)
        .background(Color(red: 0.24, green: 0.24, blue: 0.24))
        .cornerRadius(20)
    }
}

#Preview("MenuBar Popover - High Attention") {
    MenuBarPopoverView(coordinator: MockNudgeCoordinator.highAttention)
        .frame(width: 400, height: 900)
}

#Preview("MenuBar Popover - Inactive") {
    MenuBarPopoverView(coordinator: MockNudgeCoordinator.inactive)
        .frame(width: 400, height: 900)
}
// MARK: - Mock Data for Previews

class MockNudgeCoordinator: NudgeCoordinator {
    override init(modelContext: ModelContext? = nil) {
        super.init(modelContext: nil)
    }
    
    static var highAttention: MockNudgeCoordinator {
        let coordinator = MockNudgeCoordinator()
        coordinator.isActive = true
        coordinator.currentAttentionScore = 0.85
        coordinator.confidenceLevel = 0.92
        coordinator.systemStatus = .active
        coordinator.formattedSessionDuration = "1:23:45"
        coordinator.attentionScoreDisplay = "High Attention"
        coordinator.activeInsights = ["Excellent focus", "Perfect posture"]
        return coordinator
    }
    
    static var mediumAttention: MockNudgeCoordinator {
        let coordinator = MockNudgeCoordinator()
        coordinator.isActive = true
        coordinator.currentAttentionScore = 0.55
        coordinator.confidenceLevel = 0.75
        coordinator.systemStatus = .active
        coordinator.formattedSessionDuration = "45:12"
        coordinator.attentionScoreDisplay = "Medium Attention"
        coordinator.activeInsights = ["Moderate focus", "Some distractions"]
        return coordinator
    }
    
    static var lowAttention: MockNudgeCoordinator {
        let coordinator = MockNudgeCoordinator()
        coordinator.isActive = true
        coordinator.currentAttentionScore = 0.25
        coordinator.confidenceLevel = 0.68
        coordinator.systemStatus = .active
        coordinator.formattedSessionDuration = "08:30"
        coordinator.attentionScoreDisplay = "Low Attention"
        coordinator.activeInsights = ["Low focus detected", "Multiple distractions"]
        return coordinator
    }
    
    static var inactive: MockNudgeCoordinator {
        let coordinator = MockNudgeCoordinator()
        coordinator.isActive = false
        coordinator.currentAttentionScore = 0.0
        coordinator.confidenceLevel = 0.0
        coordinator.systemStatus = .paused
        coordinator.formattedSessionDuration = "00:00"
        coordinator.attentionScoreDisplay = "Inactive"
        coordinator.activeInsights = []
        return coordinator
    }
}
