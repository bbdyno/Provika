import CoreGraphics
import CoreText
import Foundation

/// Generates an unsigned reading copy without changing any authoritative artifact.
enum EvidencePDFReportGenerator {
    enum Error: Swift.Error { case contextCreationFailed }

    private static let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
    private static let textBounds = CGRect(x: 50, y: 52, width: 512, height: 688)

    static func write(
        claim: PhotoEvidenceClaimV2,
        language: EvidenceReportLanguage = .english,
        to url: URL
    ) throws {
        let copy = EvidenceReportCopy.localized(language)
        let body = reportBody(claim: claim, copy: copy)
        let attributed = attributedBody(body, language: language)
        let framesetter = CTFramesetterCreateWithAttributedString(attributed as CFAttributedString)

        guard let context = CGContext(url as CFURL, mediaBox: nil, nil) else {
            throw Error.contextCreationFailed
        }

        var consumed = 0
        repeat {
            context.beginPDFPage([kCGPDFContextMediaBox: pageBounds] as CFDictionary)
            context.saveGState()
            context.textMatrix = .identity
            context.translateBy(x: 0, y: pageBounds.height)
            context.scaleBy(x: 1, y: -1)

            let path = CGMutablePath()
            path.addRect(textBounds)
            let range = CFRange(location: consumed, length: 0)
            let frame = CTFramesetterCreateFrame(framesetter, range, path, nil)
            CTFrameDraw(frame, context)
            let visible = CTFrameGetVisibleStringRange(frame)
            consumed += max(visible.length, 1)

            context.restoreGState()
            context.endPDFPage()
        } while consumed < attributed.length

        context.closePDF()
    }

    private static func reportBody(claim: PhotoEvidenceClaimV2, copy: EvidenceReportCopy) -> String {
        var sections = [
            copy.title,
            "",
            "\(copy.packageID): \(claim.packageID.uuidString)",
            "\(copy.deviceTime): \(bounded(claim.capture.deviceTime))"
        ]
        if let location = claim.location {
            sections.append("\(copy.location): \(location.lat), \(location.lng) (±\(location.horizontalAccuracyMeters)m)")
        }
        sections += ["", copy.displayCopy, copy.originalEvidencePackage, copy.unsigned, copy.derivativeGuidance]
        return sections.joined(separator: "\n")
    }

    private static func attributedBody(_ body: String, language: EvidenceReportLanguage) -> NSAttributedString {
        let base = CTFontCreateUIFontForLanguage(.system, 11, language.rawValue as CFString)
            ?? CTFontCreateWithName("Helvetica" as CFString, 11, nil)
        // CTFont's cascade supplies CJK glyph fallback. This explicit probe keeps
        // malformed/non-renderable input from silently selecting a symbol-only font.
        let characters = Array(body.utf16)
        var glyphs = Array(repeating: CGGlyph(), count: characters.count)
        _ = CTFontGetGlyphsForCharacters(base, characters, &glyphs, characters.count)
        let paragraph = CTParagraphStyleCreate(nil, 0)
        return NSAttributedString(
            string: body,
            attributes: [
                kCTFontAttributeName as NSAttributedString.Key: base,
                kCTForegroundColorAttributeName as NSAttributedString.Key: CGColor(gray: 0.08, alpha: 1),
                kCTParagraphStyleAttributeName as NSAttributedString.Key: paragraph
            ]
        )
    }

    private static func bounded(_ value: String) -> String {
        String(value.prefix(512)).replacingOccurrences(of: "\u{0000}", with: "")
    }
}
