import AppKit
import Combine
import SwiftUI
import os

@MainActor
final class AppState: ObservableObject {

    static let shared = AppState()

    // MARK: - Managers

    private(set) lazy var permissionsManager = PermissionsManager(appState: self)
    private(set) lazy var menuBarManager = MenuBarManager(appState: self)
    private(set) lazy var menuBarItemManager = MenuBarItemManager(appState: self)
    private(set) lazy var eventManager = EventManager(appState: self)
    private(set) lazy var hotkeyManager = HotkeyManager(appState: self)
    private(set) lazy var itemImageCache = MenuBarItemImageCache(appState: self)

    // MARK: - Published State

    @Published var isDropdownVisible = false
    @Published var isSetupComplete = false

    // MARK: - Logging

    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.bonmenu", category: "AppState")

    // MARK: - Cancellables

    private var cancellables = Set<AnyCancellable>()

    // MARK: - References

    weak var appDelegate: AppDelegate?
    private var settingsWindow: NSWindow?

    private init() {}

    // MARK: - Setup

    func performSetup() {
        guard !isSetupComplete else { return }

        Self.logger.info("Performing app setup...")

        menuBarManager.performSetup()
        menuBarItemManager.performSetup()
        eventManager.performSetup()
        hotkeyManager.performSetup()
        itemImageCache.performSetup()

        configureCancellables()

        isSetupComplete = true
        Self.logger.info("App setup complete.")
    }

    private func configureCancellables() {
        // When dropdown visibility changes, update the panel
        $isDropdownVisible
            .removeDuplicates()
            .sink { [weak self] visible in
                guard let self else { return }
                if visible {
                    self.menuBarManager.showDropdown()
                } else {
                    self.menuBarManager.hideDropdown()
                }
            }
            .store(in: &cancellables)

        // When items update, refresh image cache
        menuBarItemManager.$itemCache
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] cache in
                self?.itemImageCache.updateCache(for: cache.allItems)
            }
            .store(in: &cancellables)
    }

    // MARK: - Settings

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Bonmenu Preferences"
            window.center()
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(
                rootView: SettingsView()
                    .environmentObject(self)
            )
            settingsWindow = window
        }

        activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Activation

    func activate() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func deactivate() {
        NSApp.setActivationPolicy(.accessory)
    }
}
