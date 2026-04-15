import CoreImage
import CoreLocation
import UIKit

final class OverlayRenderer {
    private let ciContext: CIContext
    private var cachedTimestampImage: CIImage?
    private var cachedTimestampSecond: Int = -1

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
        let fontSize = CGFloat(height) * 0.03

        // 타임스탬프 (좌상단)
        let timestampText = timestamp.overlayString
        let topLeftImage = renderText(
            timestampText,
            fontSize: fontSize,
            position: CGPoint(x: 20, y: CGFloat(height) - fontSize - 20),
            maxWidth: CGFloat(width)
        )

        // GPS (우상단)
        let locationText = locationString(location)
        let topRightImage = renderText(
            locationText,
            fontSize: fontSize * 0.85,
            position: CGPoint(
                x: CGFloat(width) - measureTextWidth(locationText, fontSize: fontSize * 0.85) - 20,
                y: CGFloat(height) - fontSize - 20
            ),
            maxWidth: CGFloat(width)
        )

        // 기기 정보 (하단 중앙)
        let footerText = "Provika v\(deviceInfo.appVersion) · \(deviceInfo.model)"
        let footerWidth = measureTextWidth(footerText, fontSize: fontSize * 0.75)
        let footerImage = renderText(
            footerText,
            fontSize: fontSize * 0.75,
            position: CGPoint(
                x: (CGFloat(width) - footerWidth) / 2,
                y: 20
            ),
            maxWidth: CGFloat(width)
        )

        // 합성
        var composited = baseImage
        composited = topLeftImage.composited(over: composited)
        composited = topRightImage.composited(over: composited)
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
        let lat = String(format: "%.4f", loc.coordinate.latitude)
        let lng = String(format: "%.4f", loc.coordinate.longitude)
        let speed = loc.speed >= 0 ? String(format: "%.0f km/h", loc.speed * 3.6) : "-- km/h"
        let heading = loc.course >= 0 ? String(format: "%.0f°", loc.course) : "--°"
        return "\(lat), \(lng) · \(speed) · \(heading)"
    }

    private func renderText(
        _ text: String,
        fontSize: CGFloat,
        position: CGPoint,
        maxWidth: CGFloat
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
