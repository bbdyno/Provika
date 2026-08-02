import Foundation

/// Maintained, locale-aware boundary for evidence-integrity presentation copy.
/// Korean (`ko`), English (`en`), and Simplified Chinese (`zh-Hans`) are scanned.
enum ChinaClaimsPolicy {
    enum Locale: String, CaseIterable, Codable {
        case ko
        case en
        case zhHans = "zh-Hans"
    }

    enum ReviewStatus: String, Codable {
        case awaitingEvidence = "AWAITING_EVIDENCE"
    }

    struct Finding: Equatable {
        let locale: Locale
        let phrase: String
        let range: Range<String.Index>
    }

    static let schemaVersion = "1.0"
    static let qualifiedReviewStatus: ReviewStatus = .awaitingEvidence

    /// These phrases overstate what an integrity package can establish.
    static let prohibitedClaims: [Locale: [String]] = [
        .ko: [
            "절대적 진실", "진품을 보장", "영구 위변조 불가", "법원 인정",
            "사법적 효력 보장", "공식 인증", "진짜 시간", "진짜 위치"
        ],
        .en: [
            "absolute truth", "guaranteed authentic", "permanently tamper-proof",
            "court accepted", "guaranteed legal acceptance", "officially certified",
            "true time", "true location"
        ],
        .zhHans: [
            "绝对真实", "保证真品", "永久防篡改", "法院认可", "保证法律效力",
            "官方认证", "真实时间", "真实位置"
        ]
    ]

    /// Returns all prohibited fragments without altering or approving the input.
    static func findings(in text: String, locale: Locale) -> [Finding] {
        prohibitedClaims[locale, default: []].compactMap { phrase in
            guard let range = text.range(of: phrase, options: [.caseInsensitive, .diacriticInsensitive]) else {
                return nil
            }
            return Finding(locale: locale, phrase: phrase, range: range)
        }
    }

    static func permits(_ text: String, locale: Locale) -> Bool {
        findings(in: text, locale: locale).isEmpty
    }
}
