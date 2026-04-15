//
//  OverlayRenderer.swift
//  Provika
//
//  Created by bbdyno on 4/16/26.
//

import CoreImage
import CoreLocation
import UIKit

final class OverlayRenderer {
    private let ciContext: CIContext

    struct DeviceInfo {
        let model: String
        let appVersion: String
    }

    init() {
        ciContext = CIContext(options: [.useSoftwareRenderer: false])
    }

    func render(
        pixelBuffer: CVPixelBuffer,
        location: CLLocation?,
        deviceInfo: DeviceInfo,
        timestamp: Date = Date()
    ) -> CVPixelBuffer? {
        let baseImage = CIImage(cvPixelBuffer: pixelBuffer)
        let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let layout = OverlayLayout(width: width, height: height)

        let timestampText = timestamp.overlayString
        let locationText = locationString(location)
        let footerText = "Provika v\(deviceInfo.appVersion) · \(deviceInfo.model)"

        // 합성
        var composited = baseImage

        if layout.isPortrait {
            let maxWidth = width - (layout.margin * 2)
            let footerFontSize = fittedFontSize(
                footerText,
                preferredSize: layout.footerFontSize,
                maximumWidth: maxWidth
            )
            let locationFontSize = fittedFontSize(
                locationText,
                preferredSize: layout.fontSize,
                maximumWidth: maxWidth
            )
            let timestampFontSize = fittedFontSize(
                timestampText,
                preferredSize: layout.fontSize,
                maximumWidth: maxWidth
            )

            let bottomY = layout.margin
            let middleY = bottomY + (layout.lineHeight(for: footerFontSize) + layout.lineSpacing)
            let topY = middleY + (layout.lineHeight(for: locationFontSize) + layout.lineSpacing)

            let footerImage = renderText(
                footerText,
                fontSize: footerFontSize,
                position: CGPoint(x: layout.margin, y: bottomY)
            )
            let locationImage = renderText(
                locationText,
                fontSize: locationFontSize,
                position: CGPoint(x: layout.margin, y: middleY)
            )
            let timestampImage = renderText(
                timestampText,
                fontSize: timestampFontSize,
                position: CGPoint(x: layout.margin, y: topY)
            )

            composited = footerImage.composited(over: composited)
            composited = locationImage.composited(over: composited)
            composited = timestampImage.composited(over: composited)
        } else {
            let footerFontSize = fittedFontSize(
                footerText,
                preferredSize: layout.footerFontSize,
                maximumWidth: width * 0.36
            )
            let footerWidth = measureTextWidth(footerText, fontSize: footerFontSize)
            let leftMaximumWidth = max(width - footerWidth - (layout.margin * 3), width * 0.44)
            let timestampFontSize = fittedFontSize(
                timestampText,
                preferredSize: layout.fontSize,
                maximumWidth: leftMaximumWidth
            )
            let locationFontSize = fittedFontSize(
                locationText,
                preferredSize: layout.fontSize,
                maximumWidth: leftMaximumWidth
            )

            let locationImage = renderText(
                locationText,
                fontSize: locationFontSize,
                position: CGPoint(x: layout.margin, y: layout.margin)
            )
            let timestampImage = renderText(
                timestampText,
                fontSize: timestampFontSize,
                position: CGPoint(
                    x: layout.margin,
                    y: layout.margin + layout.lineHeight(for: locationFontSize) + layout.lineSpacing
                )
            )
            let footerImage = renderText(
                footerText,
                fontSize: footerFontSize,
                position: CGPoint(
                    x: width - footerWidth - layout.margin,
                    y: layout.margin
                )
            )

            composited = timestampImage.composited(over: composited)
            composited = locationImage.composited(over: composited)
            composited = footerImage.composited(over: composited)
        }

        // 새 CVPixelBuffer로 출력
        var output: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(width),
            Int(height),
            CVPixelBufferGetPixelFormatType(pixelBuffer),
            nil,
            &output
        )
        if let output {
            ciContext.render(composited, to: output)
        }
        return output
    }

    private func locationString(_ location: CLLocation?) -> String {
        guard let loc = location else { return "GPS: --" }
        let lat = String(format: "%.6f", loc.coordinate.latitude)
        let lng = String(format: "%.6f", loc.coordinate.longitude)
        return "GPS: \(lat), \(lng)"
    }

    private func renderText(
        _ text: String,
        fontSize: CGFloat,
        position: CGPoint
    ) -> CIImage {
        let font = UIFont(name: "Menlo-Bold", size: fontSize) ?? UIFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
            .strokeColor: UIColor.black,
            .strokeWidth: -2.0
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let size = attributedString.size()

        let renderer = UIGraphicsImageRenderer(size: size)
        let uiImage = renderer.image { _ in
            attributedString.draw(at: .zero)
        }

        guard let cgImage = uiImage.cgImage else {
            return CIImage.empty()
        }

        return CIImage(cgImage: cgImage)
            .transformed(by: CGAffineTransform(translationX: position.x, y: position.y))
    }

    private func fittedFontSize(
        _ text: String,
        preferredSize: CGFloat,
        maximumWidth: CGFloat
    ) -> CGFloat {
        let minimumScale: CGFloat = 0.76
        let minimumSize = preferredSize * minimumScale
        var size = preferredSize

        while size > minimumSize && measureTextWidth(text, fontSize: size) > maximumWidth {
            size -= 1
        }

        return max(size, minimumSize)
    }

    private func measureTextWidth(_ text: String, fontSize: CGFloat) -> CGFloat {
        let font = UIFont(name: "Menlo-Bold", size: fontSize) ?? UIFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return (text as NSString).size(withAttributes: attributes).width
    }
}

private struct OverlayLayout {
    let isPortrait: Bool
    let margin: CGFloat
    let fontSize: CGFloat
    let footerFontSize: CGFloat
    let lineSpacing: CGFloat

    init(width: CGFloat, height: CGFloat) {
        let shortSide = min(width, height)
        self.isPortrait = height >= width
        self.margin = max(12, shortSide * 0.018)
        self.fontSize = shortSide * (isPortrait ? 0.0175 : 0.0185)
        self.footerFontSize = fontSize * 0.9
        self.lineSpacing = fontSize * 0.34
    }

    func lineHeight(for fontSize: CGFloat) -> CGFloat {
        fontSize * 1.12
    }
}
