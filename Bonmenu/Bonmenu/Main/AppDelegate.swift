import AppKit
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.bonmenu", category: "AppDelegate")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let appState = AppState.shared
        appState.appDelegate = self

        // Hide default menu bar items to save space
        if let mainMenu = NSApp.mainMenu {
            for item in mainMenu.items where item.title != "Bonmenu" {
                item.isHidden = true
            }
        }

        logger.info("Application did finish launching.")

        // Always proceed with setup — don't block on permissions.
        // AXIsProcessTrusted() is unreliable with ad-hoc code signing (Xcode Debug builds).
        // The app will work for detection; moving items will gracefully fail if not trusted.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            appState.performSetup()

            // If accessibility is not granted, show a non-blocking hint
            if !appState.permissionsManager.isAccessibilityGranted {
                self.logger.warning("Accessibility permission not detected (may be a code-signing issue). Showing hint.")
                appState.permissionsManager.showPermissionsHint()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        AppState.shared.deactivate()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("Application will terminate.")
    }
}
