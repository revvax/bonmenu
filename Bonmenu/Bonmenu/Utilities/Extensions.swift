import AppKit
import SwiftUI

// MARK: - NSScreen

extension NSScreen {
    /// Whether this screen has a notch (camera housing).
    var hasNotch: Bool {
        safeAreaInsets.top > 0
    }

    /// Approximate width consumed by the notch area.
    var notchWidth: CGFloat {
        hasNotch ? 200 : 0
    }

    /// The height of the menu bar on this screen.
    var menuBarHeight: CGFloat {
        frame.height - visibleFrame.height - visibleFrame.origin.y
    }
}

// MARK: - NSRunningApplication

extension NSRunningApplication {
    /// The application's display name, falling back to localized name or process name.
    var displayName: String {
        localizedName ?? bundleIdentifier?.components(separatedBy: ".").last ?? "Unknown"
    }
}

// MARK: - CGRect

extension CGRect {
    /// The center point of the rectangle.
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}

// MARK: - View

extension View {
    /// Applies a condition-based modifier.
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
