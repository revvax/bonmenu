import SwiftUI

/// Header row at the top of the dropdown showing the app name and hidden count.
struct DropdownHeaderView: View {
    let hiddenCount: Int

    var body: some View {
        HStack {
            Text("Bonmenu")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))

            Spacer()

            Text("\(hiddenCount) hidden")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
}
