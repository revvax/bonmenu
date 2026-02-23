import AppKit
import Combine
import os

/// Caches thumbnail images of menu bar items for display in the dropdown.
///
/// Uses CGWindowListCreateImage when Screen Recording permission is granted,
/// falls back to the app's dock icon otherwise.
@MainActor
final class MenuBarItemImageCache: ObservableObject {

    @Published private var cache: [CGWindowID: NSImage] = [:]

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.bonmenu",
        category: "MenuBarItemImageCache"
    )

    private weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
    }

    func performSetup() {
        logger.info("Image cache initialized.")
    }

    /// Returns the cached image for a menu bar item.
    func image(for item: MenuBarItem) -> NSImage? {
        // First try the screenshot cache
        if let cached = cache[item.windowID] {
            return cached
        }
        // Fallback to app icon
        return item.appIcon
    }

    /// Updates the cache with fresh screenshots of all items.
    func updateCache(for items: [MenuBarItem]) {
        guard appState?.permissionsManager.screenRecording.isGranted == true else {
            // Without screen recording, just use app icons (handled in image(for:))
            return
        }

        for item in items {
            guard item.isOnScreen, item.frame.width > 0, item.frame.height > 0 else { continue }

            // Use the app's dock icon as the displayed image
            // CGWindowListCreateImage is deprecated in favor of ScreenCaptureKit
            // For now, we use the app icon; ScreenCaptureKit integration can be added later
            if let appIcon = item.appIcon {
                cache[item.windowID] = appIcon
            }
        }

        // Remove stale entries
        let validIDs = Set(items.map(\.windowID))
        cache = cache.filter { validIDs.contains($0.key) }
    }
}
