import SwiftUI

/// Footer with "Preferences" button.
struct DropdownFooterView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Button {
            appState.isDropdownVisible = false
            appState.showSettings()
        } label: {
            Text("Preferences")
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(FooterButtonStyle())
        .padding(8)
    }
}

// MARK: - Footer Button Style

private struct FooterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.1 : 0.06))
            )
            .foregroundStyle(.white.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white.opacity(0.06), lineWidth: 0.5)
            )
    }
}
