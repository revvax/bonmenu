import Foundation
import AppKit
import CoreGraphics
import Combine
import os

/// Manages the Screen Recording permission check.
///
/// Screen Recording access is **optional** for Bonmenu.
/// It enables:
/// - Capturing menu bar item thumbnails for display in the dropdown
/// - Without it, we fall back to the app's dock icon
@MainActor
final class ScreenRecordingPermission: ObservableObject {

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.bonmenu",
        category: "ScreenRecordingPermission"
    )

    @Published private(set) var isGranted = false

    init() {
        isGranted = checkScreenRecording()
    }

    /// Checks whether Screen Recording access is currently granted.
    ///
    /// Uses the common technique: if CGWindowListCopyWindowInfo returns
    /// window names for windows we don't own, screen recording is granted.
    func check() -> Bool {
        let granted = checkScreenRecording()
        isGranted = granted
        return granted
    }

    private func checkScreenRecording() -> Bool {
        let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] ?? []

        let myPID = ProcessInfo.processInfo.processIdentifier

        for window in windowList {
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t,
                  pid != myPID else { continue }

            // If we can read the window name of another process, screen recording is granted
            if window[kCGWindowName as String] as? String != nil {
                return true
            }
        }

        return false
    }

    /// Opens System Settings to the Screen Recording pane.
    func openSettings() {
        let url = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        if let settingsURL = URL(string: url) {
            NSWorkspace.shared.open(settingsURL)
        }
        logger.info("Opened Screen Recording settings.")
    }
}
