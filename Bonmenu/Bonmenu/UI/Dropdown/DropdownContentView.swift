import SwiftUI

/// Root SwiftUI view inside the dropdown panel.
///
/// Simplified layout: Header → Hidden items list → Footer
struct DropdownContentView: View {
    @ObservedObject var appState: AppState

    private var hiddenItems: [MenuBarItem] {
        appState.menuBarItemManager.itemCache.hiddenItems
    }

    var body: some View {
        VStack(spacing: 0) {
            DropdownHeaderView(hiddenCount: hiddenItems.count)

            divider

            // Hidden items list (or empty state)
            if hiddenItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(.white.opacity(0.25))
                    Text("No hidden items")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(hiddenItems.enumerated()), id: \.element.id) { index, item in
                        DropdownItemView(
                            item: item,
                            index: index,
                            appState: appState
                        )
                    }
                }
                .padding(.horizontal, 8)
            }

            divider

            DropdownFooterView(appState: appState)
        }
        .frame(width: Constants.dropdownWidth)
        .background(dropdownBackground)
        .clipShape(RoundedRectangle(cornerRadius: Constants.dropdownCornerRadius))
        .overlay(
            PrismaticBorderView(cornerRadius: Constants.dropdownCornerRadius)
        )
        .shadow(color: .black.opacity(0.3), radius: 30, y: 15)
    }

    // MARK: - Components

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.06))
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var dropdownBackground: some View {
        if #available(macOS 26.0, *) {
            ultraThinMaterial
        } else {
            ultraThinMaterial
        }
    }

    private var ultraThinMaterial: some View {
        ZStack {
            Color.black.opacity(0.4)
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
            LinearGradient(
                colors: [
                    .white.opacity(0.08),
                    .white.opacity(0.02),
                    .clear
                ],
                startPoint: .top,
                endPoint: .center
            )
        }
    }
}

// MARK: - NSVisualEffectView Bridge

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
