import Combine
import CoreGraphics
import AppKit
import os

/// Detects, caches, and manages menu bar items.
///
/// Detection strategy (active overflow via divider):
/// 1. Query menu bar item windows via CGSGetProcessMenuBarWindowList
/// 2. Filter out system processes and own windows (chevron + divider)
/// 3. Classify by position relative to the ControlItem divider:
///    - Items right of the divider → visible
///    - Items left of the divider (pushed off-screen by 10,000px width) → hidden
@MainActor
final class MenuBarItemManager: ObservableObject {

    // MARK: - Item Cache

    struct ItemCache {
        var visibleItems: [MenuBarItem] = []
        var hiddenItems: [MenuBarItem] = []

        var allItems: [MenuBarItem] {
            visibleItems + hiddenItems
        }

        var totalCount: Int {
            visibleItems.count + hiddenItems.count
        }
    }

    @Published private(set) var itemCache = ItemCache()

    // MARK: - Private

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.bonmenu",
        category: "MenuBarItemManager"
    )

    private weak var appState: AppState?
    private var scanTimer: AnyCancellable?

    /// Apple system processes whose menu bar items we don't show in the dropdown.
    private static let systemProcessNames: Set<String> = [
        "Control Center",
        "SystemUIServer",
        "Spotlight",
        "Siri",
        "TextInputMenuAgent",
        "TextInputSwitcher",
        "AirPlayUIAgent",
        "WiFiAgent",
    ]

    /// Bundle IDs of Apple system items to exclude.
    private static let systemBundleIDs: Set<String> = [
        "com.apple.controlcenter",
        "com.apple.Spotlight",
        "com.apple.Siri",
        "com.apple.systemuiserver",
        "com.apple.TextInputMenuAgent",
        "com.apple.TextInputSwitcher",
    ]

    // MARK: - Init

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Setup

    func performSetup() {
        logger.info("Starting menu bar item scanning...")
        scanMenuBarItems()

        scanTimer = Timer.publish(
            every: Constants.menuBarScanInterval,
            on: .main,
            in: .common
        )
        .autoconnect()
        .sink { [weak self] _ in
            self?.scanMenuBarItems()
        }
    }

    // MARK: - Scanning

    func scanMenuBarItems() {
        let myPID = ProcessInfo.processInfo.processIdentifier

        // ── Step 1: Get actual menu bar item window IDs from CGS ──
        // CGSGetProcessMenuBarWindowList returns ONLY windows registered as NSStatusItem,
        // unlike CGWindowList layer-25 which catches tooltips, notifications, background agents.
        let menuBarWindowIDs = Bridging.getMenuBarItemWindowList()

        guard !menuBarWindowIDs.isEmpty else {
            itemCache = ItemCache()
            logger.debug("CGS returned no menu bar windows")
            return
        }

        // ── Step 2: Get on-screen set for reliable visibility check ──
        let onScreenIDs = Bridging.getOnScreenMenuBarItemWindowList()

        // ── Step 3: Get metadata via public API for owner info ──
        let descriptions = Bridging.getWindowDescriptions(for: menuBarWindowIDs)
        var descByID: [CGWindowID: [String: Any]] = [:]
        for desc in descriptions {
            if let wid = desc[kCGWindowNumber as String] as? CGWindowID {
                descByID[wid] = desc
            }
        }

        let menuBarHeight = NSScreen.main?.menuBarHeight ?? 37

        // ── Step 4: Build MenuBarItem for each window ──
        // Collect our own window IDs to exclude (chevron + divider)
        var ownWindowIDs = Set<CGWindowID>()
        if let chevronWindow = appState?.menuBarManager.statusItem?.button?.window,
           let wid = CGWindowID(exactly: chevronWindow.windowNumber) {
            ownWindowIDs.insert(wid)
        }
        if let dividerWID = appState?.menuBarManager.controlItem?.windowID {
            ownWindowIDs.insert(dividerWID)
        }

        var items: [MenuBarItem] = []

        for windowID in menuBarWindowIDs {
            // Skip our own windows (chevron + divider) by window ID
            // On macOS 26, the public API may misattribute our windows to Control Center
            if ownWindowIDs.contains(windowID) { continue }
            // Get frame via CGS (more reliable on macOS 26)
            let frame: CGRect
            if let cgsFrame = Bridging.getWindowFrame(for: windowID), cgsFrame != .zero {
                frame = cgsFrame
            } else if let desc = descByID[windowID],
                      let bounds = desc[kCGWindowBounds as String] as? [String: CGFloat],
                      let x = bounds["X"], let y = bounds["Y"],
                      let w = bounds["Width"], let h = bounds["Height"] {
                frame = CGRect(x: x, y: y, width: w, height: h)
            } else {
                continue
            }

            // Strict geometric validation: must be in the menu bar area
            guard frame.height > 0 && frame.height <= menuBarHeight + 5 else { continue }
            guard frame.origin.y <= menuBarHeight + 2 else { continue }
            guard frame.width > 0 && frame.width < 500 else { continue } // No real item is >500px wide

            // Get owner info from descriptions
            let desc = descByID[windowID]
            let ownerPID = desc?[kCGWindowOwnerPID as String] as? pid_t ?? 0

            // Skip items with no owner or owned by us
            guard ownerPID > 0 && ownerPID != myPID else { continue }

            var ownerName = desc?[kCGWindowOwnerName as String] as? String
            let windowTitle = desc?[kCGWindowName as String] as? String

            // macOS 26 workaround (FB18327911): many items are misreported as
            // owned by Control Center regardless of locale. Check by bundle ID.
            let resolvedApp = NSRunningApplication(processIdentifier: ownerPID)
            let resolvedBundleID = resolvedApp?.bundleIdentifier

            if resolvedBundleID == "com.apple.controlcenter" && resolvedApp?.localizedName != ownerName {
                // Genuine Control Center item but name may be localized — keep ownerName as-is
            } else if resolvedBundleID != nil && resolvedBundleID != "com.apple.controlcenter" {
                // Misattributed — resolve to the real app name
                ownerName = resolvedApp?.localizedName ?? ownerName
            }

            // Skip Apple system processes (by name)
            if let name = ownerName, Self.systemProcessNames.contains(name) {
                continue
            }

            // Skip Apple system processes (by bundle ID) — handles localized names
            if let bid = resolvedBundleID, Self.systemBundleIDs.contains(bid) {
                continue
            }

            let isOnScreen = onScreenIDs.contains(windowID)

            let item = MenuBarItem(
                windowID: windowID,
                frame: frame,
                ownerPID: ownerPID,
                ownerName: ownerName,
                windowTitle: windowTitle,
                isOnScreen: isOnScreen
            )

            if let bundleID = item.bundleIdentifier,
               Self.systemBundleIDs.contains(bundleID) {
                continue
            }

            items.append(item)
        }

        // ── Step 5: Deduplicate by PID (keep item with widest frame per app) ──
        var bestPerPID: [pid_t: MenuBarItem] = [:]
        for item in items {
            if let existing = bestPerPID[item.ownerPID] {
                if item.frame.width > existing.frame.width {
                    bestPerPID[item.ownerPID] = item
                }
            } else {
                bestPerPID[item.ownerPID] = item
            }
        }

        let deduped = Array(bestPerPID.values)
            .sorted { $0.frame.origin.x < $1.frame.origin.x }

        // ── Step 6: Classify into visible vs hidden ──
        classifyItems(deduped)

        logger.debug("Scan: \(self.itemCache.visibleItems.count) visible, \(self.itemCache.hiddenItems.count) hidden")
    }

    // MARK: - Classification (Divider-based)

    private func classifyItems(_ items: [MenuBarItem]) {
        // Get the divider's frame to classify items relative to it
        guard let controlItem = appState?.menuBarManager.controlItem,
              let dividerWindow = controlItem.statusItem.button?.window else {
            // No divider available — fall back to on-screen check
            var visible: [MenuBarItem] = []
            var hidden: [MenuBarItem] = []
            for item in items {
                if item.isOnScreen && item.frame.origin.x >= 0 {
                    visible.append(item)
                } else {
                    hidden.append(item)
                }
            }
            itemCache = ItemCache(visibleItems: visible, hiddenItems: hidden)
            return
        }

        let dividerMaxX = dividerWindow.frame.maxX

        var visible: [MenuBarItem] = []
        var hidden: [MenuBarItem] = []

        for item in items {
            // Items with minX >= divider's maxX are to the right of the divider → visible
            if item.frame.minX >= dividerMaxX {
                visible.append(item)
            } else {
                hidden.append(item)
            }
        }

        itemCache = ItemCache(visibleItems: visible, hiddenItems: hidden)
    }

    // MARK: - Move Items via CGEvent Drag

    enum MoveError: Error {
        case itemNotMovable
        case eventCreationFailed
    }

    /// Moves a menu bar item to a target X position using simulated Command+Drag.
    func moveItem(_ item: MenuBarItem, toX targetX: CGFloat) async throws {
        guard item.isMovable else {
            throw MoveError.itemNotMovable
        }

        let startPoint = CGPoint(x: item.frame.midX, y: item.frame.midY)
        let endPoint = CGPoint(x: targetX, y: startPoint.y)

        logger.info("Moving '\(item.displayName)' from x=\(startPoint.x) to x=\(endPoint.x)")

        guard let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                                       mouseCursorPosition: startPoint, mouseButton: .left),
              let mouseDrag = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged,
                                       mouseCursorPosition: endPoint, mouseButton: .left),
              let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                                     mouseCursorPosition: endPoint, mouseButton: .left)
        else { throw MoveError.eventCreationFailed }

        mouseDown.flags = .maskCommand
        mouseDrag.flags = .maskCommand

        mouseDown.post(tap: .cgSessionEventTap)
        try await Task.sleep(for: .milliseconds(50))
        mouseDrag.post(tap: .cgSessionEventTap)
        try await Task.sleep(for: .milliseconds(50))
        mouseUp.post(tap: .cgSessionEventTap)

        try await Task.sleep(for: .milliseconds(300))
        scanMenuBarItems()
    }

    /// Toggles an item's visibility by moving it across the divider boundary.
    func toggleVisibility(for item: MenuBarItem) async {
        let isCurrentlyHidden = itemCache.hiddenItems.contains { $0.windowID == item.windowID }

        if isCurrentlyHidden {
            // Move to the right of the divider (visible area)
            guard let controlItem = appState?.menuBarManager.controlItem,
                  let dividerWindow = controlItem.statusItem.button?.window else { return }
            let targetX = dividerWindow.frame.maxX + 10
            try? await moveItem(item, toX: targetX)
        } else {
            // Move to the left of the divider (hidden area)
            try? await moveItem(item, toX: -100)
        }
    }

    /// Clicks a menu bar item to trigger its action.
    func clickItem(_ item: MenuBarItem) async {
        guard item.frame != .zero else {
            // Item has no known position — try to find it by activating the app
            if let app = item.owningApplication {
                app.activate()
            }
            return
        }

        let point = CGPoint(x: item.frame.midX, y: item.frame.midY)

        guard let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                                  mouseCursorPosition: point, mouseButton: .left),
              let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                                mouseCursorPosition: point, mouseButton: .left)
        else { return }

        down.post(tap: .cgSessionEventTap)
        try? await Task.sleep(for: .milliseconds(30))
        up.post(tap: .cgSessionEventTap)
    }

    // MARK: - Temp Show and Click

    /// Temporarily reveals all hidden items, clicks the target item, then re-hides.
    ///
    /// 1. Collapse divider (length → 0) so items slide on-screen
    /// 2. Wait for layout update
    /// 3. Re-scan to get updated frames
    /// 4. Click the item at its new position
    /// 5. After a delay, re-expand the divider to hide items again
    func tempShowAndClick(_ item: MenuBarItem) async {
        guard let controlItem = appState?.menuBarManager.controlItem else {
            // No divider — just click directly
            await clickItem(item)
            return
        }

        // Dismiss the dropdown first
        appState?.isDropdownVisible = false

        // Collapse the divider to reveal hidden items
        controlItem.state = .showItems

        // Wait for macOS to update the layout
        try? await Task.sleep(for: .milliseconds(200))

        // Re-scan to get updated positions
        scanMenuBarItems()

        // Find the item's updated frame by matching PID
        let updatedItem = itemCache.allItems.first { $0.ownerPID == item.ownerPID }
            ?? item

        // Click the item
        await clickItem(updatedItem)

        // Wait before re-hiding so the user can interact with the opened menu
        try? await Task.sleep(for: .seconds(2))

        // Re-expand the divider
        controlItem.state = .hideItems

        // Re-scan after hiding
        try? await Task.sleep(for: .milliseconds(200))
        scanMenuBarItems()
    }
}
