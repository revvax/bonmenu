import CoreGraphics
import AppKit

/// Wraps a CGWindowID with parsed metadata from the window server.
struct WindowInfo: Equatable, Hashable, Identifiable {

    let windowID: CGWindowID
    let frame: CGRect
    let title: String?
    let windowName: String?
    let layer: Int
    let ownerPID: pid_t
    let ownerName: String?
    let isOnScreen: Bool
    let alpha: CGFloat

    var id: CGWindowID { windowID }

    /// Whether this window is a menu bar status item.
    var isMenuBarItem: Bool {
        layer == kCGStatusWindowLevel
    }

    /// The NSRunningApplication that owns this window, if still running.
    var owningApplication: NSRunningApplication? {
        NSRunningApplication(processIdentifier: ownerPID)
    }

    /// The bundle identifier of the owning application.
    var bundleIdentifier: String? {
        owningApplication?.bundleIdentifier
    }

    // MARK: - Initializers

    /// Creates a WindowInfo from a CGWindowID by querying the window server.
    init?(windowID: CGWindowID) {
        let cfIDs = [NSNumber(value: windowID)] as CFArray
        guard let descriptions = CGWindowListCreateDescriptionFromArray(cfIDs) as? [[String: Any]],
              let info = descriptions.first else {
            return nil
        }
        self.init(dictionary: info)
    }

    /// Creates a WindowInfo from a window description dictionary.
    init?(dictionary: [String: Any]) {
        guard let windowID = dictionary[kCGWindowNumber as String] as? CGWindowID,
              let layer = dictionary[kCGWindowLayer as String] as? Int,
              let ownerPID = dictionary[kCGWindowOwnerPID as String] as? pid_t else {
            return nil
        }

        self.windowID = windowID
        self.layer = layer
        self.ownerPID = ownerPID
        self.ownerName = dictionary[kCGWindowOwnerName as String] as? String
        self.title = dictionary[kCGWindowName as String] as? String
        self.windowName = dictionary[kCGWindowName as String] as? String
        self.isOnScreen = (dictionary[kCGWindowIsOnscreen as String] as? Bool) ?? false
        self.alpha = (dictionary[kCGWindowAlpha as String] as? CGFloat) ?? 1.0

        // Parse bounds
        if let boundsDict = dictionary[kCGWindowBounds as String] as? [String: CGFloat],
           let x = boundsDict["X"],
           let y = boundsDict["Y"],
           let width = boundsDict["Width"],
           let height = boundsDict["Height"] {
            self.frame = CGRect(x: x, y: y, width: width, height: height)
        } else {
            // Fallback to CGS API
            if let cgsFrame = Bridging.getWindowFrame(for: windowID) {
                self.frame = cgsFrame
            } else {
                self.frame = .zero
            }
        }
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(windowID)
    }

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.windowID == rhs.windowID
    }
}
