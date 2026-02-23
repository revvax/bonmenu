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
        let menuBarWindowIDs = Bridging.getMenuBarItemWindowList()

        guard !menuBarWindowIDs.isEmpty else {
            itemCache = ItemCache()
            logger.debug("CGS returned no menu bar windows")
            return
        }

        // ── Step 2: Get on-screen set for reliable visibility check ──
        let onScreenIDs = Bridging.getOnScreenMenuBarItemWindowList()

        // ── Step 3: Get metadata via public API for owner info ──
        // On macOS 26, CGWindowListCreateDescriptionFromArray returns nothing for CGS window IDs.
        // Use CGWindowListCopyWindowInfo with .optionAll and filter by layer 25 instead.
        let allWindowDescs = Bridging.getAllWindows(option: [.optionAll])
        var descByID: [CGWindowID: [String: Any]] = [:]
        for desc in allWindowDescs {
            guard let wid = desc[kCGWindowNumber as String] as? CGWindowID,
                  let layer = desc[kCGWindowLayer as String] as? Int,
                  layer == 25 else { continue }
            descByID[wid] = desc
        }

        let menuBarHeight = NSScreen.main?.menuBarHeight ?? 37

        // ── Step 4: Collect our own window IDs to exclude ──
        var ownWindowIDs = Set<CGWindowID>()
        if let chevronWindow = appState?.menuBarManager.statusItem?.button?.window,
           let wid = CGWindowID(exactly: chevronWindow.windowNumber) {
            ownWindowIDs.insert(wid)
        }
        if let dividerWID = appState?.menuBarManager.controlItem?.windowID {
            ownWindowIDs.insert(dividerWID)
        }

        // ── Step 5: Build a lookup of accessory apps for owner resolution ──
        // On macOS 26, all items report as Control Center (FB18327911).
        // We match menu bar windows to third-party apps by checking which
        // .accessory apps are running and have status bar items.
        let accessoryApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .accessory && $0.processIdentifier != myPID }
        var accessoryByPID: [pid_t: String] = [:]
        for app in accessoryApps {
            if let bid = app.bundleIdentifier {
                accessoryByPID[app.processIdentifier] = bid
            }
        }
        // Detect macOS 26 PID-misattribution: check if ALL items share a single PID
        let reportedPIDs = Set(menuBarWindowIDs.compactMap {
            descByID[$0]?[kCGWindowOwnerPID as String] as? pid_t
        })
        let allMisattributed = reportedPIDs.count == 1
            && reportedPIDs.first.map({ Self.systemBundleIDs.contains(
                NSRunningApplication(processIdentifier: $0)?.bundleIdentifier ?? ""
            ) }) == true

        // ── Step 6: Build MenuBarItem for each window ──
        var items: [MenuBarItem] = []

        for windowID in menuBarWindowIDs {
            if ownWindowIDs.contains(windowID) { continue }

            // Get frame
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

            // Geometric validation
            guard frame.height > 0 && frame.height <= menuBarHeight + 5 else { continue }
            guard frame.origin.y <= menuBarHeight + 2 else { continue }
            guard frame.width > 0 && frame.width < 500 else { continue }

            let desc = descByID[windowID]
            let ownerPID = desc?[kCGWindowOwnerPID as String] as? pid_t ?? 0
            let ownerName = desc?[kCGWindowOwnerName as String] as? String
            let windowTitle = desc?[kCGWindowName as String] as? String

            // Skip items with no owner
            guard ownerPID > 0 else { continue }
            // Skip our own PID (works when PIDs are reported correctly)
            if ownerPID == myPID { continue }

            if !allMisattributed {
                // PIDs are reliable — use traditional filtering
                if let name = ownerName, Self.systemProcessNames.contains(name) { continue }
                let resolvedBID = NSRunningApplication(processIdentifier: ownerPID)?.bundleIdentifier
                if let bid = resolvedBID, Self.systemBundleIDs.contains(bid) { continue }
            }
            // When allMisattributed: skip NO items — the divider position handles everything.
            // System items (clock, Wi-Fi, etc.) stay right of the divider = visible,
            // and only hidden (overflow) items appear in the dropdown.

            let isOnScreen = onScreenIDs.contains(windowID)

            let item = MenuBarItem(
                windowID: windowID,
                frame: frame,
                ownerPID: ownerPID,
                ownerName: ownerName,
                windowTitle: windowTitle,
                isOnScreen: isOnScreen
            )

            items.append(item)
        }

        // ── Step 7: Sort by X position (no PID-dedup when misattributed) ──
        if allMisattributed {
            // All PIDs are the same — keep every individual window
            items.sort { $0.frame.origin.x < $1.frame.origin.x }
        } else {
            // Deduplicate by PID (keep widest frame per app)
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
            items = Array(bestPerPID.values).sorted { $0.frame.origin.x < $1.frame.origin.x }
        }

        // ── Step 8: Classify into visible vs hidden ──
        classifyItems(items)

        logger.debug("Scan: \(self.itemCache.visibleItems.count) visible, \(self.itemCache.hiddenItems.count) hidden (misattributed=\(allMisattributed))")
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

        // Find the item's updated frame by matching window ID
        let updatedItem = itemCache.allItems.first { $0.windowID == item.windowID }
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
