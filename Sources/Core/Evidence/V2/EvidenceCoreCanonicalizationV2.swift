import Foundation

/// The single locale-neutral boundary for signed V2 Evidence Core observations.
///
/// This type deliberately operates only on the existing V2 claim schema. It does
/// not derive display strings, localized application values, or reverse-geocoded
/// addresses. User-authored `context` is carried through unchanged.
enum EvidenceCoreCanonicalizationV2 {
    enum Error: Swift.Error, Equatable {
        case invalidCaptureTime
    }

    /// Rebuilds the claim at the Core boundary, replacing only the media digest
    /// and representing the capture instant in UTC.
    static func frozenClaim(
        replacingMediaDigest digest: String,
        in claim: PhotoEvidenceClaimV2
    ) throws -> PhotoEvidenceClaimV2 {
        PhotoEvidenceClaimV2(
            packageID: claim.packageID,
            media: .init(
                fileName: claim.media.fileName,
                mediaType: claim.media.mediaType,
                pixelWidth: claim.media.pixelWidth,
                pixelHeight: claim.media.pixelHeight,
                sha256: digest
            ),
            capture: .init(deviceTime: try utcTimestamp(from: claim.capture.deviceTime)),
            // Bundle display names are presentation values and may be localized.
            // A signature instead records the stable product identity.
            app: .init(name: canonicalAppName, version: claim.app.version, build: claim.app.build),
            device: .init(model: claim.device.model, systemVersion: claim.device.systemVersion),
            location: claim.location,
            context: claim.context
        )
    }

    /// Produces stable UTF-8 JSON bytes without consulting the process locale.
    static func canonicalClaimData(for claim: PhotoEvidenceClaimV2) throws -> Data {
        try canonicalEncoder().encode(claim)
    }

    private static func canonicalEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    private static let canonicalAppName = "Provika"

    private static func utcTimestamp(from value: String) throws -> String {
        guard let date = try? utcISO8601.parse(value) else {
            throw Error.invalidCaptureTime
        }
        let milliseconds = canonicalMilliseconds(in: value)
        let wholeSeconds = canonicalUTCWholeSecondISO8601.format(date)
        guard wholeSeconds.hasSuffix("Z") else {
            throw Error.invalidCaptureTime
        }
        return "\(wholeSeconds.dropLast()).\(milliseconds)Z"
    }

    /// Parsing and formatting are both explicitly pinned to UTC rather than the
    /// process locale or calendar. The fractional-second parser also accepts
    /// whole-second legacy capture instants.
    private static let utcISO8601 = Date.ISO8601FormatStyle(
        timeZoneSeparator: .colon,
        includingFractionalSeconds: true,
        timeZone: TimeZone(secondsFromGMT: 0)!
    )

    private static let canonicalUTCWholeSecondISO8601 = Date.ISO8601FormatStyle(
        timeZoneSeparator: .colon,
        includingFractionalSeconds: false,
        timeZone: TimeZone(secondsFromGMT: 0)!
    )

    /// Keep the existing three-digit signed schema representation without
    /// relying on binary floating-point rendering of fractional seconds.
    private static func canonicalMilliseconds(in value: String) -> String {
        guard let decimalIndex = value.firstIndex(of: ".") else { return "000" }
        let fractionStart = value.index(after: decimalIndex)
        let fraction = value[fractionStart...].prefix { $0.isNumber }
        return String(fraction.prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0)
    }
}
