import Foundation
import CoreGraphics
import os

/// Namespace for safe wrappers around private CGS API calls.
enum Bridging {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.bonmenu",
        category: "Bridging"
    )

    // MARK: - Window Listing

    /// Returns all menu bar item window IDs across all processes.
    static func getMenuBarItemWindowList() -> [CGWindowID] {
        let cid = CGSMainConnectionID()
        let maxCount: Int32 = 256
        var windowIDs = [CGWindowID](repeating: 0, count: Int(maxCount))
        var actualCount: Int32 = 0

        let error = CGSGetProcessMenuBarWindowList(
            cid, 0, maxCount, &windowIDs, &actualCount
        )

        guard error == .success else {
            logger.warning("CGSGetProcessMenuBarWindowList failed with error: \(error.rawValue)")
            return []
        }

        return Array(windowIDs.prefix(Int(actualCount)))
    }

    /// Returns all on-screen window IDs.
    static func getOnScreenWindowList() -> [CGWindowID] {
        let cid = CGSMainConnectionID()
        let maxCount: Int32 = 1024
        var windowIDs = [CGWindowID](repeating: 0, count: Int(maxCount))
        var actualCount: Int32 = 0

        let error = CGSGetOnScreenWindowList(
            cid, 0, maxCount, &windowIDs, &actualCount
        )

        guard error == .success else {
            logger.warning("CGSGetOnScreenWindowList failed with error: \(error.rawValue)")
            return []
        }

        return Array(windowIDs.prefix(Int(actualCount)))
    }

    // MARK: - Window Properties

    /// Returns the screen-space frame for a window.
    static func getWindowFrame(for windowID: CGWindowID) -> CGRect? {
        let cid = CGSMainConnectionID()
        var rect = CGRect.zero

        let error = CGSGetScreenRectForWindow(cid, windowID, &rect)

        guard error == .success else {
            return nil
        }

        return rect
    }

    /// Returns the window level for a window.
    static func getWindowLevel(for windowID: CGWindowID) -> Int32? {
        let cid = CGSMainConnectionID()
        var level: Int32 = 0

        let error = CGSGetWindowLevel(cid, windowID, &level)

        guard error == .success else {
            return nil
        }

        return level
    }

    // MARK: - Combined Queries

    /// Returns menu bar item window IDs that are currently on-screen.
    /// This is the intersection of getMenuBarItemWindowList() and getOnScreenWindowList().
    static func getOnScreenMenuBarItemWindowList() -> Set<CGWindowID> {
        let allMenuBar = Set(getMenuBarItemWindowList())
        let onScreen = Set(getOnScreenWindowList())
        return allMenuBar.intersection(onScreen)
    }

    // MARK: - Window Info via Public API

    /// Creates WindowInfo descriptions using the public CGWindowList API.
    /// Note: On macOS 26, owner names may incorrectly report "Control Center" (FB18327911).
    static func getWindowDescriptions(for windowIDs: [CGWindowID]) -> [[String: Any]] {
        let cfIDs = windowIDs.map { NSNumber(value: $0) } as CFArray
        guard let descriptions = CGWindowListCreateDescriptionFromArray(cfIDs) as? [[String: Any]] else {
            return []
        }
        return descriptions
    }

    /// Returns all windows matching the given options using the public API.
    static func getAllWindows(
        option: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    ) -> [[String: Any]] {
        guard let windowList = CGWindowListCopyWindowInfo(option, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return windowList
    }
}
