import AppKit
import os

/// Coordinates all event monitors for the app.
///
/// Handles:
/// - Click outside dropdown to dismiss
/// - Escape key to dismiss
/// - Space/desktop changes to dismiss
@MainActor
final class EventManager {

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.bonmenu",
        category: "EventManager"
    )

    private weak var appState: AppState?

    private var globalClickMonitor: GlobalEventMonitor?
    private var localKeyMonitor: LocalEventMonitor?
    private var spaceChangeObserver: NSObjectProtocol?

    init(appState: AppState) {
        self.appState = appState
    }

    func performSetup() {
        setupGlobalClickMonitor()
        setupLocalKeyMonitor()
        setupSpaceChangeObserver()
        logger.info("Event monitors active.")
    }

    // MARK: - Click Outside

    private func setupGlobalClickMonitor() {
        globalClickMonitor = GlobalEventMonitor(
            mask: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            Task { @MainActor in
                guard let self, let appState = self.appState else { return }
                guard appState.isDropdownVisible else { return }

                // Check if the click is inside the dropdown panel
                let clickLocation = event.locationInWindow
                if let panel = appState.menuBarManager.dropdownPanel {
                    let panelFrame = panel.frame
                    // Convert screen coordinates
                    let screenPoint = NSEvent.mouseLocation
                    if !panelFrame.contains(screenPoint) {
                        // Also check if clicking the status item button itself
                        if let buttonWindow = appState.menuBarManager.statusItem?.button?.window {
                            if !buttonWindow.frame.contains(screenPoint) {
                                appState.isDropdownVisible = false
                            }
                        } else {
                            appState.isDropdownVisible = false
                        }
                    }
                }
            }
        }
        globalClickMonitor?.start()
    }

    // MARK: - Escape Key

    private func setupLocalKeyMonitor() {
        localKeyMonitor = LocalEventMonitor(
            mask: .keyDown
        ) { [weak self] event in
            guard let self else { return event }
            // Escape key = keyCode 53
            if event.keyCode == 53 {
                Task { @MainActor in
                    if self.appState?.isDropdownVisible == true {
                        self.appState?.isDropdownVisible = false
                    }
                }
                return nil // Consume the event
            }
            return event
        }
        localKeyMonitor?.start()
    }

    // MARK: - Space Change

    private func setupSpaceChangeObserver() {
        spaceChangeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.appState?.isDropdownVisible = false
            }
        }
    }
}
