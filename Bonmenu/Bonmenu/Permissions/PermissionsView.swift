import SwiftUI

/// Non-blocking onboarding view that explains permissions.
///
/// The app is already running when this shows — it's just a helpful hint.
/// User can close it anytime with "Continue" or the close button.
struct PermissionsView: View {
    @ObservedObject var manager: PermissionsManager

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "menubar.arrow.down.rectangle")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.tint)

                Text("Welcome to Bonmenu")
                    .font(.title.bold())

                Text("Bonmenu works best with these permissions.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 14) {
                // Accessibility
                PermissionRow(
                    icon: "hand.raised.fill",
                    iconColor: .blue,
                    title: "Accessibility",
                    description: "Needed to rearrange menu bar items. Open System Settings → Privacy & Security → Accessibility and add Bonmenu.",
                    isRequired: true,
                    isGranted: manager.isAccessibilityGranted,
                    action: {
                        manager.openAccessibilitySettings()
                    },
                    actionLabel: "Open Settings"
                )

                // Screen Recording
                PermissionRow(
                    icon: "camera.metering.partial",
                    iconColor: .green,
                    title: "Screen Recording",
                    description: "Optional. Enables menu bar item thumbnails.",
                    isRequired: false,
                    isGranted: manager.isScreenRecordingGranted,
                    action: {
                        manager.screenRecording.openSettings()
                    },
                    actionLabel: "Open Settings"
                )
            }
            .padding(.horizontal, 8)

            Spacer()

            // Action buttons
            VStack(spacing: 10) {
                Button {
                    manager.refreshAll()
                } label: {
                    Label("Refresh Status", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)

                Button {
                    manager.dismissPermissionsWindow()
                } label: {
                    Text("Continue — Bonmenu is already running")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .frame(width: 500, height: 460)
    }
}

// MARK: - Permission Row

private struct PermissionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let isRequired: Bool
    let isGranted: Bool
    let action: () -> Void
    var actionLabel: String = "Grant"

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.headline)
                    if isRequired {
                        Text("Required")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    } else {
                        Text("Optional")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.15))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                    }
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
            } else {
                Button(actionLabel) {
                    action()
                }
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
