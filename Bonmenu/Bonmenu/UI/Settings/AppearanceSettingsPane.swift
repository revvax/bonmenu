import SwiftUI

/// Appearance settings: dropdown size, animation speed, prismatic effect.
struct AppearanceSettingsPane: View {

    @AppStorage(Constants.defaultsKeyPrismaticBorderEnabled)
    private var prismaticBorderEnabled = true

    @AppStorage(Constants.defaultsKeyAnimationSpeed)
    private var animationSpeed = 1.0

    var body: some View {
        Form {
            Section("Dropdown") {
                HStack {
                    Text("Width")
                    Spacer()
                    Text("\(Int(Constants.dropdownWidth))pt")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Effects") {
                Toggle("Prismatic rainbow border", isOn: $prismaticBorderEnabled)

                HStack {
                    Text("Animation Speed")
                    Slider(value: $animationSpeed, in: 0.5...2.0, step: 0.25)
                    Text("\(animationSpeed, specifier: "%.2f")x")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 40)
                }
            }
        }
        .formStyle(.grouped)
    }
}
