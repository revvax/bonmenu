import Foundation

/// Represents a logical section in the menu bar dropdown.
enum MenuBarSection: String, CaseIterable, Identifiable {
    case visible
    case hidden
    case alwaysHidden

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .visible: return "Visible"
        case .hidden: return "Hidden"
        case .alwaysHidden: return "Always Hidden"
        }
    }

    var isCollapsible: Bool {
        self != .visible
    }
}
