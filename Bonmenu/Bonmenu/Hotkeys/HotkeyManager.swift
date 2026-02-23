import Foundation
import os
// NOTE: KeyboardShortcuts SPM package must be added to the Xcode project.
// import KeyboardShortcuts

/// Manages the global keyboard shortcut for toggling the dropdown.
///
/// Default hotkey: ⌥⌘B (Option + Command + B)
///
/// Uses the KeyboardShortcuts package for:
/// - User-customizable shortcuts
/// - Mac App Store compatible implementation
/// - Built-in recorder UI for Settings
@MainActor
final class HotkeyManager {

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.bonmenu",
        category: "HotkeyManager"
    )

    private weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
    }

    func performSetup() {
        // TODO: Uncomment when KeyboardShortcuts package is added
        /*
        KeyboardShortcuts.onKeyUp(for: .toggleDropdown) { [weak self] in
            Task { @MainActor in
                self?.appState?.isDropdownVisible.toggle()
            }
        }
        */
        logger.info("Hotkey manager initialized.")
    }
}

// TODO: Uncomment when KeyboardShortcuts package is added
/*
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleDropdown = Self(
        "toggleBonmenuDropdown",
        default: .init(.b, modifiers: [.option, .command])
    )
}
*/
