import AppKit
import SwiftUI
import os

/// A floating, non-activating panel that hosts the Liquid Glass dropdown content.
///
/// Positioned directly below the Bonmenu chevron trigger in the menu bar.
/// Does not steal focus from the frontmost application.
@MainActor
final class DropdownPanel: NSPanel {

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.bonmenu",
        category: "DropdownPanel"
    )

    private let hostingView: NSHostingView<DropdownContentView>

    init(appState: AppState) {
        let contentView = DropdownContentView(appState: appState)
        self.hostingView = NSHostingView(rootView: contentView)

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Constants.dropdownWidth, height: 10),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: true
        )

        self.level = .mainMenu + 1
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        self.animationBehavior = .utilityWindow
        self.contentView = hostingView

        logger.info("DropdownPanel initialized.")
    }

    // MARK: - Show / Dismiss

    func show(relativeTo statusItem: NSStatusItem) {
        guard let button = statusItem.button,
              let buttonWindow = button.window else {
            logger.warning("Cannot show dropdown: status item button or window unavailable.")
            return
        }

        let buttonFrame = buttonWindow.frame
        let screen = buttonWindow.screen ?? NSScreen.main!

        // Calculate panel size from content
        let contentSize = hostingView.fittingSize
        let panelWidth = Constants.dropdownWidth
        let panelHeight = min(contentSize.height, Constants.dropdownMaxHeight)

        // Position: centered below the trigger button, inset from right edge
        let panelX = buttonFrame.midX - panelWidth / 2
        let panelY = screen.frame.maxY - screen.menuBarHeight - panelHeight - 4

        // Ensure panel stays within screen bounds
        let clampedX = max(
            screen.frame.minX + 8,
            min(panelX, screen.frame.maxX - panelWidth - 8)
        )

        let panelFrame = NSRect(
            x: clampedX,
            y: panelY,
            width: panelWidth,
            height: panelHeight
        )

        setFrame(panelFrame, display: true)
        orderFrontRegardless()

        logger.debug("Panel shown at frame: \(panelFrame.debugDescription)")
    }

    func dismiss() {
        orderOut(nil)
        logger.debug("Panel dismissed.")
    }

    // MARK: - Key handling

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Let the event manager handle Escape
        super.keyDown(with: event)
    }
}
