import SwiftUI
import ApplicationServices
import os

/// Coordinates all permission checks and manages the onboarding window.
///
/// Permissions are non-blocking: the app always starts and shows a hint
/// if accessibility is missing. This avoids issues with ad-hoc code signing
/// where AXIsProcessTrusted() returns false even when the user has granted access.
@MainActor
final class PermissionsManager: ObservableObject {

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.bonmenu",
        category: "PermissionsManager"
    )

    // MARK: - Published State (flat for SwiftUI observability)

    @Published var isAccessibilityGranted = false
    @Published var isScreenRecordingGranted = false
    @Published var hasRequiredPermissions = false

    // MARK: - Sub-managers

    let accessibility = AccessibilityPermission()
    let screenRecording = ScreenRecordingPermission()

    // MARK: - Private

    private weak var appState: AppState?
    private var permissionsWindow: NSWindow?

    init(appState: AppState) {
        self.appState = appState
        refreshAll()
    }

    // MARK: - Refresh

    func refreshAll() {
        isAccessibilityGranted = AXIsProcessTrusted()
        isScreenRecordingGranted = screenRecording.check()
        hasRequiredPermissions = isAccessibilityGranted
    }

    // MARK: - Non-blocking Hint

    /// Shows a non-blocking permissions hint window.
    /// The app is already running — this is just informational.
    func showPermissionsHint() {
        if permissionsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 460),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.titlebarAppearsTransparent = true
            window.title = "Bonmenu Permissions"
            window.center()
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(
                rootView: PermissionsView(manager: self)
            )
            permissionsWindow = window
        }

        permissionsWindow?.makeKeyAndOrderFront(nil)
        appState?.activate()
    }

    /// Dismisses the permissions window.
    func dismissPermissionsWindow() {
        permissionsWindow?.close()
        permissionsWindow = nil
        appState?.deactivate()
    }

    /// Opens System Settings to the Accessibility pane.
    func openAccessibilitySettings() {
        let url = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let settingsURL = URL(string: url) {
            NSWorkspace.shared.open(settingsURL)
        }
    }
}
