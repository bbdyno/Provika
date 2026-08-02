import Foundation

/// Locale-neutral semantic requirements whose visible strings come from the catalogs.
enum MultilingualAccessibilityPolicy {
    enum Surface: String, CaseIterable {
        case capture
        case gallery
        case verification
        case settings
        case purchase
        case export
    }

    enum Status: String, CaseIterable {
        case recording
        case busy
        case success
        case failure
    }

    struct Contract: Equatable {
        let surface: Surface
        let requiresLocalizedLabel: Bool
        let requiresNonColorCue: Bool
        let requiresDynamicType: Bool
        let announcesStatus: Bool
    }

    static let contracts: [Contract] = Surface.allCases.map { surface in
        Contract(
            surface: surface,
            requiresLocalizedLabel: true,
            requiresNonColorCue: true,
            requiresDynamicType: true,
            announcesStatus: [.capture, .verification, .purchase, .export].contains(surface)
        )
    }

    static let focusOrder: [Surface] = [.capture, .gallery, .verification, .settings, .purchase, .export]
    static let supportedLocales = Set(["ko", "en", "zh-Hans", "zh-Hant", "ja"])
    static let qualifiedVoiceOverReviewStatus = "AWAITING_EVIDENCE"

    static func accessibilityAnnouncement(for status: Status, localizedValue: String) -> String {
        localizedValue
    }
}
