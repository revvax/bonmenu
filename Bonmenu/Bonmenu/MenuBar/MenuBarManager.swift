import AppKit
import Combine
import os

/// Manages the Bonmenu status item (chevron trigger + divider) and the dropdown panel.
///
/// The chevron status item serves a dual purpose:
/// - **Trigger**: Clicking it opens/closes the dropdown
/// - **Divider**: When hiding items, it expands to 10,000px (icon stays at the right edge),
///   pushing all items to its left off-screen. When showing items, it collapses to its
///   normal icon width.
///
/// This single-item approach ensures no gap exists between the divider and trigger,
/// preventing macOS from placing other apps' items in between.
@MainActor
final class MenuBarManager: ObservableObject {

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.bonmenu",
        category: "MenuBarManager"
    )

    // MARK: - Overflow State

    enum OverflowState {
        case hideItems
        case showItems
    }

    /// Controls whether hidden items are pushed off-screen or revealed.
    var overflowState: OverflowState = .hideItems {
        didSet { updateStatusItemLength() }
    }

    /// The combined chevron + divider status item.
    private(set) var statusItem: NSStatusItem?

    /// The dropdown panel.
    private(set) var dropdownPanel: DropdownPanel?

    private weak var appState: AppState?
    private var cancellables = Set<AnyCancellable>()

    /// The normal width of the chevron icon area.
    private static let chevronWidth: CGFloat = 24
    /// The expanded width that pushes items off-screen.
    private static let expandedWidth: CGFloat = 10_000

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Computed

    /// The CGWindowID of the status item's window, used for scan exclusion and classification.
    var statusItemWindowID: CGWindowID? {
        guard let window = statusItem?.button?.window else { return nil }
        let wn = window.windowNumber
        guard wn > 0 else { return nil }
        return CGWindowID(clamping: wn)
    }

    // MARK: - Setup

    func performSetup() {
        createStatusItem()
        createDropdownPanel()
        logger.info("MenuBarManager setup complete.")
    }

    // MARK: - Status Item (Chevron + Divider)

    private func createStatusItem() {
        // Remove existing item if any
        if let existing = statusItem {
            NSStatusBar.system.removeStatusItem(existing)
        }

        // Start expanded — items to our left are immediately pushed off-screen
        let item = NSStatusBar.system.statusItem(withLength: Self.expandedWidth)
        item.autosaveName = "BonmenuTrigger"
        item.behavior = .removalAllowed

        if let button = item.button {
            let symbolConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            let image = NSImage(
                systemSymbolName: "chevron.down",
                accessibilityDescription: "Bonmenu"
            )?.withSymbolConfiguration(symbolConfig)
            image?.isTemplate = true
            button.image = image
            // Place the icon at the right (trailing) edge of the button.
            // The rest of the 10,000px width extends to the left, pushing items off-screen.
            button.imagePosition = .imageRight
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Bonmenu"
            // Clear title to avoid extra space
            button.title = ""
        }

        statusItem = item
        overflowState = .hideItems
        logger.info("Status item created (chevron + divider, width = \(Self.expandedWidth)).")
    }

    private func updateStatusItemLength() {
        guard let statusItem else { return }

        switch overflowState {
        case .hideItems:
            statusItem.length = Self.expandedWidth
            logger.debug("Chevron expanded — hiding items.")
        case .showItems:
            statusItem.length = Self.chevronWidth
            logger.debug("Chevron collapsed — showing items.")
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

        menu.addItem(NSMenuItem(
            title: "Preferences\u{2026}",
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
