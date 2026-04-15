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
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let fontSize = CGFloat(height) * 0.016
        let margin: CGFloat = 12
        let lineHeight: CGFloat = fontSize * 2.0
        let h = CGFloat(height)
        let w = CGFloat(width)

        // 좌하단 1행: 타임스탬프
        let timestampText = timestamp.overlayString
        let topLine1 = renderText(
            timestampText,
            fontSize: fontSize,
            position: CGPoint(x: margin, y: margin + lineHeight)
        )

        // 좌하단 2행: GPS 좌표
        let locationText = locationString(location)
        let topLine2 = renderText(
            locationText,
            fontSize: fontSize,
            position: CGPoint(x: margin, y: margin)
        )

        // 우하단: 기기 정보
        let footerText = "Provika v\(deviceInfo.appVersion) · \(deviceInfo.model)"
        let footerFontSize = fontSize * 0.9
        let footerWidth = measureTextWidth(footerText, fontSize: footerFontSize)
        let footerImage = renderText(
            footerText,
            fontSize: footerFontSize,
            position: CGPoint(
                x: w - footerWidth - margin,
                y: margin
            )
        )

        // 합성
        var composited = baseImage
        composited = topLine1.composited(over: composited)
        composited = topLine2.composited(over: composited)
        composited = footerImage.composited(over: composited)

        // 새 CVPixelBuffer로 출력
        var output: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
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

    private func measureTextWidth(_ text: String, fontSize: CGFloat) -> CGFloat {
        let font = UIFont(name: "Menlo-Bold", size: fontSize) ?? UIFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return (text as NSString).size(withAttributes: attributes).width
    }
}
