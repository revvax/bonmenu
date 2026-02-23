import AppKit
import Combine
import os

/// Manages the Bonmenu status item (chevron trigger) and the dropdown panel.
///
/// Handles:
/// - Creating and maintaining the chevron status item in the menu bar
/// - Monitoring visibility and recreating if pushed off-screen
/// - Managing the dropdown panel lifecycle
@MainActor
final class MenuBarManager: ObservableObject {

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.bonmenu",
        category: "MenuBarManager"
    )

    /// Our status item in the system menu bar.
    private(set) var statusItem: NSStatusItem?

    /// Invisible divider item that pushes items off-screen for overflow management.
    private(set) var controlItem: ControlItem?

    /// The dropdown panel.
    private(set) var dropdownPanel: DropdownPanel?

    private weak var appState: AppState?
    private var cancellables = Set<AnyCancellable>()
    private var visibilityTimer: AnyCancellable?

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Setup

    func performSetup() {
        createStatusItem()
        createControlItem()
        createDropdownPanel()
        startVisibilityMonitoring()
        logger.info("MenuBarManager setup complete.")
    }

    // MARK: - Status Item

    private func createStatusItem() {
        // Remove existing item if any
        if let existing = statusItem {
            NSStatusBar.system.removeStatusItem(existing)
        }

        // Create with a very small fixed length to minimize space usage
        let item = NSStatusBar.system.statusItem(withLength: 24)

        // autosaveName helps macOS remember the user's preferred position.
        // The user should Command+drag it right after the Apple system icons.
        item.autosaveName = "BonmenuTrigger"

        // Make the item behave as a "removal allowed" item so macOS treats it
        // with higher priority for positioning
        item.behavior = .removalAllowed

        if let button = item.button {
            let symbolConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            let image = NSImage(
                systemSymbolName: "chevron.down",
                accessibilityDescription: "Bonmenu"
            )?.withSymbolConfiguration(symbolConfig)
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageOnly
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])

            // Tooltip to guide user
            button.toolTip = "Bonmenu — Tip: ⌘-drag to reposition after system icons"
        }

        statusItem = item
        logger.info("Status item created.")
    }

    // MARK: - Control Item (Divider)

    private func createControlItem() {
        controlItem = ControlItem()
    }

    // MARK: - Visibility Monitoring

    /// Monitors whether our status item is still visible.
    /// If it gets pushed off-screen by too many other items, we log a warning.
    private func startVisibilityMonitoring() {
        visibilityTimer = Timer.publish(
            every: 3.0,
            on: .main,
            in: .common
        )
        .autoconnect()
        .sink { [weak self] _ in
            self?.checkVisibility()
        }
    }

    private func checkVisibility() {
        guard let statusItem, let button = statusItem.button, let window = button.window else {
            return
        }

        let frame = window.frame
        guard let screen = NSScreen.main else { return }

        // Check if our item is visible on screen
        let isVisible = frame.origin.x >= 0 && frame.maxX <= screen.frame.width

        if !isVisible && statusItem.isVisible {
            logger.warning("Bonmenu status item was pushed off-screen! Frame: \(frame.debugDescription)")
            // The item is being clipped. We can't force a position,
            // but we can try to ensure it stays by toggling visibility.
        }
    }

    // MARK: - Click Handling

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let appState else { return }

        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            appState.isDropdownVisible.toggle()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let positionItem = NSMenuItem(
            title: "Tip: ⌘-drag this icon right next to system icons",
            action: nil,
            keyEquivalent: ""
        )
        positionItem.isEnabled = false
        menu.addItem(positionItem)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(
            title: "Preferences…",
            action: #selector(openPreferences),
            keyEquivalent: ","
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Bonmenu",
            action: #selector(quitApp),
            keyEquivalent: "q"
        ))

        for item in menu.items {
            item.target = self
        }

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil // Remove menu so left-click works again
    }

    @objc private func openPreferences() {
        appState?.showSettings()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Dropdown Panel

    private func createDropdownPanel() {
        guard let appState else { return }
        dropdownPanel = DropdownPanel(appState: appState)
    }

    func showDropdown() {
        guard let statusItem, let dropdownPanel else { return }
        dropdownPanel.show(relativeTo: statusItem)
        statusItem.button?.highlight(true)
        logger.debug("Dropdown shown.")
    }

    func hideDropdown() {
        dropdownPanel?.dismiss()
        statusItem?.button?.highlight(false)
        logger.debug("Dropdown hidden.")
    }
}
