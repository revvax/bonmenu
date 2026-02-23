import AppKit
import os

/// An invisible NSStatusItem used as a divider to control menu bar overflow.
///
/// When `state == .hideItems`, the divider expands to 10,000px, pushing all
/// items to its left off-screen. When `state == .showItems`, it collapses to 0px,
/// letting items slide back on-screen.
@MainActor
final class ControlItem {

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.bonmenu",
        category: "ControlItem"
    )

    let statusItem: NSStatusItem

    enum State {
        case hideItems
        case showItems
    }

    var state: State = .hideItems {
        didSet { updateLength() }
    }

    /// The CGWindowID of the divider's button window, used to exclude it from scans.
    var windowID: CGWindowID? {
        guard let window = statusItem.button?.window else {
            return nil
        }
        let wn = window.windowNumber
        guard wn > 0 else { return nil }
        // windowNumber is Int, CGWindowID is UInt32 — safe cast for valid window numbers
        return CGWindowID(clamping: wn)
    }

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: 10_000)
        statusItem.autosaveName = "BonmenuDivider"

        // Make the divider invisible
        if let button = statusItem.button {
            button.title = ""
            button.image = nil
            // Prevent any visual appearance
            button.appearsDisabled = true
            button.alphaValue = 0
        }

        logger.info("ControlItem created (divider length = 10000).")
    }

    private func updateLength() {
        switch state {
        case .hideItems:
            statusItem.length = 10_000
            logger.debug("Divider expanded — hiding items.")
        case .showItems:
            statusItem.length = 0
            logger.debug("Divider collapsed — showing items.")
        }
    }
}
