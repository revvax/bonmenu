import Foundation
import CoreGraphics

enum Constants {

    // MARK: - Dropdown

    static let dropdownWidth: CGFloat = 320
    static let dropdownCornerRadius: CGFloat = 16
    static let dropdownMaxHeight: CGFloat = 600

    // MARK: - Animation

    static let dropdownOpenDuration: Double = 0.35
    static let dropdownCloseDuration: Double = 0.2
    static let itemStaggerDelay: Double = 0.04
    static let prismaticRotationDuration: Double = 6.0

    // MARK: - Scanning

    static let menuBarScanInterval: TimeInterval = 2.0
    static let imageCacheRefreshInterval: TimeInterval = 5.0

    // MARK: - Item Display

    static let appIconSize: CGFloat = 32
    static let appIconCornerRadius: CGFloat = 8
    static let statusDotSize: CGFloat = 9

    // MARK: - Keys

    static let defaultsKeyAutoHideOverflow = "autoHideOverflow"
    static let defaultsKeyShowOverflowNotification = "showOverflowNotification"
    static let defaultsKeyPrismaticBorderEnabled = "prismaticBorderEnabled"
    static let defaultsKeyAnimationSpeed = "animationSpeed"
}
