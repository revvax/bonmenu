import SwiftUI

/// Advanced settings: permissions status, reset, debug.
struct AdvancedSettingsPane: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Permissions") {
                HStack {
                    Label("Accessibility", systemImage: "hand.raised.fill")
                    Spacer()
                    if appState.permissionsManager.isAccessibilityGranted {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Grant") {
                            appState.permissionsManager.accessibility.request()
                        }
                        .controlSize(.small)
                    }
                }

                HStack {
                    Label("Screen Recording", systemImage: "camera.metering.partial")
                    Spacer()
                    if appState.permissionsManager.isScreenRecordingGranted {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Open Settings") {
                            appState.permissionsManager.screenRecording.openSettings()
                        }
                        .controlSize(.small)
                    }
                }
            }

            Section("Data") {
                Button("Reset All Settings", role: .destructive) {
                    if let bundleID = Bundle.main.bundleIdentifier {
                        UserDefaults.standard.removePersistentDomain(forName: bundleID)
                    }
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Build")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}
