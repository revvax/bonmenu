import SwiftUI

/// Animated rainbow border effect that rotates around the dropdown panel.
///
/// Uses an AngularGradient with continuous hueRotation animation
/// to create a subtle, prismatic light-refraction appearance.
struct PrismaticBorderView: View {
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    let opacity: Double

    @State private var hueRotation: Double = 0

    init(
        cornerRadius: CGFloat = Constants.dropdownCornerRadius,
        lineWidth: CGFloat = 1,
        opacity: Double = 0.25
    ) {
        self.cornerRadius = cornerRadius
        self.lineWidth = lineWidth
        self.opacity = opacity
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(
                AngularGradient(
                    colors: [
                        .red,
                        .orange,
                        .yellow,
                        .green,
                        .cyan,
                        .blue,
                        .purple,
                        .pink,
                        .red
                    ],
                    center: .center
                ),
                lineWidth: lineWidth
            )
            .opacity(opacity)
            .hueRotation(.degrees(hueRotation))
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(
                    .linear(duration: Constants.prismaticRotationDuration)
                    .repeatForever(autoreverses: false)
                ) {
                    hueRotation = 360
                }
            }
    }
}
