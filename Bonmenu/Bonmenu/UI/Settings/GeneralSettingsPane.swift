import SwiftUI
// import LaunchAtLogin
// import KeyboardShortcuts

/// General settings: launch at login, hotkey, automation.
struct GeneralSettingsPane: View {
    @EnvironmentObject var appState: AppState

    @AppStorage(Constants.defaultsKeyAutoHideOverflow)
    private var autoHideOverflow = true

    @AppStorage(Constants.defaultsKeyShowOverflowNotification)
    private var showOverflowNotification = true

    var body: some View {
        Form {
            Section("Startup") {
                // TODO: Uncomment when LaunchAtLogin is added
                // LaunchAtLogin.Toggle("Launch Bonmenu at Login")
                Toggle("Launch Bonmenu at Login", isOn: .constant(false))
                    .disabled(true)
            }

            Section("Keyboard Shortcut") {
                // TODO: Uncomment when KeyboardShortcuts is added
                // KeyboardShortcuts.Recorder("Toggle Dropdown:", name: .toggleDropdown)
                HStack {
                    Text("Toggle Dropdown:")
                    Spacer()
                    Text("⌥⌘B")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.tertiary.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            Section("Automation") {
                Toggle("Automatically hide overflow items", isOn: $autoHideOverflow)
                Toggle("Show notification when items are auto-hidden", isOn: $showOverflowNotification)
            }
        }
        .formStyle(.grouped)
    }
}
