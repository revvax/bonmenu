import SwiftUI

/// A section in the dropdown (Visible or Hidden) with optional collapse.
struct DropdownSectionView: View {
    let section: MenuBarSection
    let items: [MenuBarItem]
    @Binding var isExpanded: Bool
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text(section.displayName.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
                    .tracking(0.5)

                Spacer()

                Text("\(items.count) apps")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.25))

                if section.isCollapsible {
                    Button {
                        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "eye")
                            .font(.system(size: 14))
                            .foregroundStyle(isExpanded ? Color.accentColor : .white.opacity(0.3))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Items list
            if !section.isCollapsible || isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        DropdownItemView(
                            item: item,
                            index: index,
                            appState: appState
                        )
                    }
                }
                .padding(.horizontal, 8)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    )
                )
            }
        }
    }
}
