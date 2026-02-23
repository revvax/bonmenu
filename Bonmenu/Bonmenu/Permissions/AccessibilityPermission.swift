import ApplicationServices
import os

/// Manages the Accessibility permission check and request.
///
/// Accessibility access is **required** for Bonmenu to function.
/// It enables:
/// - Reading menu bar item positions and metadata
/// - Simulating mouse events to rearrange items
/// - Querying AXUIElement hierarchy for owner identification
@MainActor
final class AccessibilityPermission: ObservableObject {

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.bonmenu",
        category: "AccessibilityPermission"
    )

    @Published private(set) var isGranted = false

    private var checkTimer: Timer?

    init() {
        isGranted = AXIsProcessTrusted()
    }

    /// Checks whether Accessibility access is currently granted.
    func check() -> Bool {
        let trusted = AXIsProcessTrusted()
        isGranted = trusted
        return trusted
    }

    /// Prompts the user to grant Accessibility access via System Settings.
    func request() {
        let options: NSDictionary = [
            "AXTrustedCheckOptionPrompt": true
        ]
        AXIsProcessTrustedWithOptions(options)
        logger.info("Requested Accessibility permission from user.")
    }

    /// Starts polling for permission changes (used during onboarding).
    func startPolling(interval: TimeInterval = 1.0) {
        stopPolling()
        checkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let wasGranted = self.isGranted
                let nowGranted = self.check()
                if !wasGranted && nowGranted {
                    self.logger.info("Accessibility permission was granted.")
                    self.stopPolling()
                }
            }
        }
    }

    /// Stops polling for permission changes.
    func stopPolling() {
        checkTimer?.invalidate()
        checkTimer = nil
    }
}
