//
//  OverlayRenderer.swift
//  Provika
//
//  Created by bbdyno on 4/16/26.
//

import CoreImage
import CoreLocation
import ImageIO
import Metal
import UIKit

final class OverlayRenderer {
    private let ciContext: CIContext

    struct DeviceInfo: Equatable {
        let model: String
        let appVersion: String
    }

    // 매 프레임 텍스트 재렌더링을 피하기 위한 캐시 (CLAUDE.md §5.2.2)
    private var timestampCache: TextCache?
    private var locationCache: TextCache?
    private var footerCache: TextCache?
    private var layoutCache: LayoutCache?

    // 출력 CVPixelBuffer 재사용을 위한 풀
    private var pixelBufferPool: CVPixelBufferPool?
    private var pixelBufferPoolKey: PoolKey?

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        // 초 단위 캐시와 맞추기 위해 밀리초는 생략 (성능 최적화)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    init() {
        if let device = MTLCreateSystemDefaultDevice() {
            ciContext = CIContext(mtlDevice: device, options: [.cacheIntermediates: false])
        } else {
            ciContext = CIContext(options: [.useSoftwareRenderer: false])
        }
    }

    // orientation: 입력은 항상 포트레이트 프레임이므로, 이 값에 따라 CIImage를 회전시키고
    // 오버레이는 회전 후 좌표계에 맞춰 배치된다. (`.up`=포트레이트 그대로, `.left`/`.right`=가로)
    func render(
        pixelBuffer: CVPixelBuffer,
        location: CLLocation?,
        deviceInfo: DeviceInfo,
        timestamp: Date = Date(),
        orientation: CGImagePropertyOrientation = .up
    ) -> CVPixelBuffer? {
        let inputWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let inputHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)

        let swapWH = (orientation == .left || orientation == .right
            || orientation == .leftMirrored || orientation == .rightMirrored)
        let width = swapWH ? inputHeight : inputWidth
        let height = swapWH ? inputWidth : inputHeight

        let layout = cachedLayout(width: width, height: height)
        let maxWidth = layout.isPortrait
            ? width - (layout.margin * 2)
            : width * 0.5

        let timestampText = Self.timestampFormatter.string(from: timestamp)
        let locationText = locationString(location)
        let footerText = "Provika v\(deviceInfo.appVersion) · \(deviceInfo.model)"

        let timestampEntry = textEntry(
            cache: &timestampCache,
            text: timestampText,
            preferredSize: layout.fontSize,
            maximumWidth: maxWidth
        )
        let locationEntry = textEntry(
            cache: &locationCache,
            text: locationText,
            preferredSize: layout.fontSize,
            maximumWidth: maxWidth
        )
        let footerMaxWidth = layout.isPortrait ? maxWidth : width * 0.36
        let footerEntry = textEntry(
            cache: &footerCache,
            text: footerText,
            preferredSize: layout.footerFontSize,
            maximumWidth: footerMaxWidth
        )

        // 회전 적용 — .oriented는 CIImage의 extent를 회전된 크기·(0,0) 원점으로 재정렬한다.
        let baseImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
        var composited = baseImage

        if layout.isPortrait {
            let bottomY = layout.margin
            let middleY = bottomY + footerEntry.size.height + layout.lineSpacing
            let topY = middleY + locationEntry.size.height + layout.lineSpacing

            composited = footerEntry.image
                .transformed(by: CGAffineTransform(translationX: layout.margin, y: bottomY))
                .composited(over: composited)
            composited = locationEntry.image
                .transformed(by: CGAffineTransform(translationX: layout.margin, y: middleY))
                .composited(over: composited)
            composited = timestampEntry.image
                .transformed(by: CGAffineTransform(translationX: layout.margin, y: topY))
                .composited(over: composited)
        } else {
            let locationTopY = layout.margin
            let timestampTopY = locationTopY + locationEntry.size.height + layout.lineSpacing
            let footerX = width - footerEntry.size.width - layout.margin

            composited = timestampEntry.image
                .transformed(by: CGAffineTransform(translationX: layout.margin, y: timestampTopY))
                .composited(over: composited)
            composited = locationEntry.image
                .transformed(by: CGAffineTransform(translationX: layout.margin, y: locationTopY))
                .composited(over: composited)
            composited = footerEntry.image
                .transformed(by: CGAffineTransform(translationX: footerX, y: layout.margin))
                .composited(over: composited)
        }

        guard let output = makePixelBuffer(width: Int(width), height: Int(height), format: format) else {
            return nil
        }
        ciContext.render(composited, to: output)
        return output
    }

    // 방향 전환·해상도 변경 시 캐시 무효화 (외부에서 호출 가능)
    func invalidateCaches() {
        timestampCache = nil
        locationCache = nil
        footerCache = nil
        layoutCache = nil
        pixelBufferPool = nil
        pixelBufferPoolKey = nil
    }

    // MARK: - Cache helpers

    private func cachedLayout(width: CGFloat, height: CGFloat) -> OverlayLayout {
        if let cache = layoutCache, cache.width == width, cache.height == height {
            return cache.layout
        }
        let layout = OverlayLayout(width: width, height: height)
        layoutCache = LayoutCache(width: width, height: height, layout: layout)
        return layout
    }

    private func textEntry(
        cache: inout TextCache?,
        text: String,
        preferredSize: CGFloat,
        maximumWidth: CGFloat
    ) -> TextCache {
        if let entry = cache,
           entry.text == text,
           entry.preferredSize == preferredSize,
           entry.maximumWidth == maximumWidth {
            return entry
        }
        let fontSize = fittedFontSize(text, preferredSize: preferredSize, maximumWidth: maximumWidth)
        let (image, size) = renderText(text, fontSize: fontSize)
        let entry = TextCache(
            text: text,
            preferredSize: preferredSize,
            maximumWidth: maximumWidth,
            image: image,
            size: size
        )
        cache = entry
        return entry
    }

    private func locationString(_ location: CLLocation?) -> String {
        guard let loc = location else { return "GPS: --" }
        let lat = String(format: "%.4f", loc.coordinate.latitude)
        let lng = String(format: "%.4f", loc.coordinate.longitude)
        return "GPS: \(lat), \(lng)"
    }

    private func renderText(_ text: String, fontSize: CGFloat) -> (CIImage, CGSize) {
        let font = UIFont(name: "Menlo-Bold", size: fontSize)
            ?? UIFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
            .strokeColor: UIColor.black,
            .strokeWidth: -2.0
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let size = attributedString.size()

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let uiImage = renderer.image { _ in
            attributedString.draw(at: .zero)
        }

        guard let cgImage = uiImage.cgImage else {
            return (CIImage.empty(), .zero)
        }
        return (CIImage(cgImage: cgImage), size)
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
        let font = UIFont(name: "Menlo-Bold", size: fontSize)
            ?? UIFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
        return (text as NSString).size(withAttributes: [.font: font]).width
    }

    private func makePixelBuffer(width: Int, height: Int, format: OSType) -> CVPixelBuffer? {
        let key = PoolKey(width: width, height: height, format: format)
        if pixelBufferPoolKey != key {
            let bufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: format,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]
            let poolAttributes: [String: Any] = [
                kCVPixelBufferPoolMinimumBufferCountKey as String: 3
            ]
            var pool: CVPixelBufferPool?
            CVPixelBufferPoolCreate(
                kCFAllocatorDefault,
                poolAttributes as CFDictionary,
                bufferAttributes as CFDictionary,
                &pool
            )
            pixelBufferPool = pool
            pixelBufferPoolKey = key
        }

        guard let pool = pixelBufferPool else { return nil }
        var output: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &output)
        guard status == kCVReturnSuccess else { return nil }
        return output
    }
}

private struct TextCache {
    let text: String
    let preferredSize: CGFloat
    let maximumWidth: CGFloat
    let image: CIImage
    let size: CGSize
}

private struct LayoutCache {
    let width: CGFloat
    let height: CGFloat
    let layout: OverlayLayout
}

private struct PoolKey: Equatable {
    let width: Int
    let height: Int
    let format: OSType
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
        // CLAUDE.md §5.2.1: 영상 높이의 3% (1080p 기준 ~32pt)
        self.margin = max(16, shortSide * 0.022)
        self.fontSize = shortSide * (isPortrait ? 0.028 : 0.030)
        self.footerFontSize = fontSize * 0.82
        self.lineSpacing = fontSize * 0.5
    }
}
