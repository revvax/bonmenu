import SwiftUI

/// A single app row in the dropdown list.
///
/// Shows: app icon, name, subtitle. Click activates the app.
struct DropdownItemView: View {
    let item: MenuBarItem
    let index: Int
    @ObservedObject var appState: AppState

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // App icon
            Group {
                if let image = appState.itemImageCache.image(for: item) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    RoundedRectangle(cornerRadius: Constants.appIconCornerRadius)
                        .fill(.white.opacity(0.08))
                        .overlay(
                            Image(systemName: "app.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.3))
                        )
                }
            }
            .frame(
                width: Constants.appIconSize,
                height: Constants.appIconSize
            )
            .clipShape(RoundedRectangle(cornerRadius: Constants.appIconCornerRadius))

            // Name + subtitle
            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)

                if let bundleID = item.bundleIdentifier {
                    Text(bundleID.components(separatedBy: ".").last ?? "")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.3))
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? .white.opacity(0.07) : .clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            Task {
                await appState.menuBarItemManager.tempShowAndClick(item)
            }
        }
    }
}
