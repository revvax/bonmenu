import CoreGraphics
import AppKit

/// Represents a single menu bar status item detected on the system.
struct MenuBarItem: Identifiable, Equatable, Hashable {

    let windowID: CGWindowID
    let frame: CGRect
    let ownerPID: pid_t
    let ownerName: String?
    let windowTitle: String?
    let isOnScreen: Bool

    var id: CGWindowID { windowID }

    // MARK: - Resolved Info

    /// The display name for the item (app name or window title).
    var displayName: String {
        if let app = owningApplication {
            return app.displayName
        }
        return ownerName ?? windowTitle ?? "Unknown"
    }

    /// The bundle identifier of the owning app.
    var bundleIdentifier: String? {
        owningApplication?.bundleIdentifier
    }

    /// The running application that owns this item.
    var owningApplication: NSRunningApplication? {
        NSRunningApplication(processIdentifier: ownerPID)
    }

    /// The app icon of the owning application.
    var appIcon: NSImage? {
        owningApplication?.icon
    }

    // MARK: - Behavior

    /// Whether this item can be moved by simulating drag events.
    var isMovable: Bool {
        !Self.immovableBundleIDs.contains(bundleIdentifier ?? "")
    }

    /// Whether this item can be hidden by the user.
    var canBeHidden: Bool {
        !Self.nonHideableBundleIDs.contains(bundleIdentifier ?? "")
    }

    /// System items that cannot be moved via drag.
    private static let immovableBundleIDs: Set<String> = [
        "com.apple.controlcenter",
        "com.apple.Spotlight",
    ]

    /// System items that should never be hidden.
    private static let nonHideableBundleIDs: Set<String> = [
        "com.apple.controlcenter",
        "com.apple.Spotlight",
    ]

    // MARK: - Init from WindowInfo

    init(windowInfo: WindowInfo) {
        self.windowID = windowInfo.windowID
        self.frame = windowInfo.frame
        self.ownerPID = windowInfo.ownerPID
        self.ownerName = windowInfo.ownerName
        self.windowTitle = windowInfo.title
        self.isOnScreen = windowInfo.isOnScreen
    }

    init(windowID: CGWindowID, frame: CGRect, ownerPID: pid_t, ownerName: String?, windowTitle: String?, isOnScreen: Bool) {
        self.windowID = windowID
        self.frame = frame
        self.ownerPID = ownerPID
        self.ownerName = ownerName
        self.windowTitle = windowTitle
        self.isOnScreen = isOnScreen
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(windowID)
    }

    static func == (lhs: MenuBarItem, rhs: MenuBarItem) -> Bool {
        lhs.windowID == rhs.windowID
    }
}
