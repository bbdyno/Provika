#if DEBUG
import Foundation
import UIKit

enum ScreenshotScreen: String {
    case camera
    case gallery
    case detail
    case settings
}

/// Deterministic, local-only content used to capture honest App Store screenshots.
/// This code is excluded from Release builds and never reads or writes user data.
enum ScreenshotFixtures {
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("-ProvikaScreenshotMode")

    static let requestedScreen: ScreenshotScreen? = {
        guard isEnabled,
              let argumentIndex = ProcessInfo.processInfo.arguments.firstIndex(of: "-ProvikaScreenshotScreen"),
              ProcessInfo.processInfo.arguments.indices.contains(argumentIndex + 1) else {
            return nil
        }
        return ScreenshotScreen(rawValue: ProcessInfo.processInfo.arguments[argumentIndex + 1])
    }()

    static let recordings: [Recording] = {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let items: [(String, TimeInterval, Double, Double, RoadScene)] = [
            ("PV-20260803-001", 48, 37.5665, 126.9780, .city),
            ("PV-20260803-002", 76, 37.5703, 126.9831, .intersection),
            ("PV-20260803-003", 34, 37.5612, 126.9947, .bridge),
            ("PV-20260803-004", 112, 37.5512, 127.0103, .night)
        ]

        return items.enumerated().map { index, item in
            let createdAt = calendar.date(byAdding: .minute, value: -(index * 19), to: now) ?? now
            return Recording(
                id: item.0,
                createdAt: createdAt,
                duration: item.1,
                fileURL: URL(fileURLWithPath: "/tmp/\(item.0).mov"),
                sidecarURL: URL(fileURLWithPath: "/tmp/\(item.0).json"),
                fileHash: "6f4b8e2d9a17c0f3b5d1e8a246c97f30b45a1d8e6c2f9b0374d8a1e5c6f2b903",
                startLatitude: item.2,
                startLongitude: item.3,
                endLatitude: item.2 + 0.0012,
                endLongitude: item.3 + 0.0018,
                userNote: nil,
                thumbnailData: roadThumbnail(scene: item.4)
            )
        }
    }()

    static var primaryRecording: Recording { recordings[0] }
    static var cameraPreviewData: Data? { roadThumbnail(scene: .city) }

    private enum RoadScene: Equatable {
        case city
        case intersection
        case bridge
        case night
    }

    private static func roadThumbnail(scene: RoadScene) -> Data? {
        let size = CGSize(width: 960, height: 540)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.pngData { context in
            let cg = context.cgContext
            let isNight = scene == .night

            let skyColors = isNight
                ? [UIColor(red: 0.04, green: 0.08, blue: 0.18, alpha: 1).cgColor,
                   UIColor(red: 0.15, green: 0.19, blue: 0.30, alpha: 1).cgColor]
                : [UIColor(red: 0.27, green: 0.63, blue: 0.90, alpha: 1).cgColor,
                   UIColor(red: 0.78, green: 0.90, blue: 0.98, alpha: 1).cgColor]
            let sky = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: skyColors as CFArray,
                locations: [0, 1]
            )!
            cg.drawLinearGradient(sky, start: .zero, end: CGPoint(x: 0, y: 350), options: [])

            let skylineColor = isNight
                ? UIColor(white: 0.12, alpha: 1)
                : UIColor(red: 0.42, green: 0.48, blue: 0.52, alpha: 1)
            skylineColor.setFill()
            for index in 0..<12 {
                let width = CGFloat(55 + (index % 3) * 16)
                let height = CGFloat(92 + (index * 37) % 145)
                UIBezierPath(
                    rect: CGRect(
                        x: CGFloat(index) * 84 - 14,
                        y: 335 - height,
                        width: width,
                        height: height
                    )
                ).fill()
            }

            if scene == .bridge {
                UIColor(white: 0.80, alpha: 1).setStroke()
                let bridge = UIBezierPath()
                bridge.move(to: CGPoint(x: 0, y: 285))
                bridge.addCurve(
                    to: CGPoint(x: 960, y: 285),
                    controlPoint1: CGPoint(x: 260, y: 130),
                    controlPoint2: CGPoint(x: 700, y: 130)
                )
                bridge.lineWidth = 9
                bridge.stroke()
            }

            UIColor(red: 0.14, green: 0.15, blue: 0.17, alpha: 1).setFill()
            let road = UIBezierPath()
            road.move(to: CGPoint(x: 300, y: 300))
            road.addLine(to: CGPoint(x: 660, y: 300))
            road.addLine(to: CGPoint(x: 960, y: 540))
            road.addLine(to: CGPoint(x: 0, y: 540))
            road.close()
            road.fill()

            UIColor(white: 0.95, alpha: 0.9).setFill()
            for lane in [-1, 1] {
                for segment in 0..<4 {
                    let nearY = CGFloat(338 + segment * 53)
                    let farY = nearY + CGFloat(25 + segment * 4)
                    let centerX = CGFloat(480 + lane * (35 + segment * 24))
                    let stripe = UIBezierPath()
                    stripe.move(to: CGPoint(x: centerX - 4, y: nearY))
                    stripe.addLine(to: CGPoint(x: centerX + 4, y: nearY))
                    stripe.addLine(to: CGPoint(x: centerX + 8, y: farY))
                    stripe.addLine(to: CGPoint(x: centerX - 8, y: farY))
                    stripe.close()
                    stripe.fill()
                }
            }

            drawCar(
                in: CGRect(x: scene == .intersection ? 535 : 445, y: 330, width: 92, height: 62),
                color: .systemRed,
                isNight: isNight
            )
            drawCar(in: CGRect(x: 660, y: 400, width: 138, height: 88), color: .systemBlue, isNight: isNight)
            drawCar(in: CGRect(x: 185, y: 420, width: 150, height: 94), color: .white, isNight: isNight)

            if scene == .intersection {
                UIColor(white: 0.95, alpha: 0.8).setFill()
                for index in 0..<7 {
                    UIBezierPath(rect: CGRect(x: CGFloat(index) * 142, y: 303, width: 82, height: 16)).fill()
                }
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd  HH:mm:ss"
            let stamp = formatter.string(from: Date()) + "   37.5665°N  126.9780°E"
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .right
            (stamp as NSString).draw(
                in: CGRect(x: 20, y: 492, width: 920, height: 28),
                withAttributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 17, weight: .medium),
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: paragraph,
                    .strokeColor: UIColor.black.withAlphaComponent(0.7),
                    .strokeWidth: -2
                ]
            )
        }
    }

    private static func drawCar(in rect: CGRect, color: UIColor, isNight: Bool) {
        color.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: rect.height * 0.18).fill()
        UIColor(white: isNight ? 0.04 : 0.15, alpha: 0.9).setFill()
        UIBezierPath(
            roundedRect: rect.insetBy(dx: rect.width * 0.20, dy: rect.height * 0.20),
            cornerRadius: 8
        ).fill()
        UIColor(red: 1, green: 0.19, blue: 0.10, alpha: 1).setFill()
        let lightSize = CGSize(width: rect.width * 0.12, height: rect.height * 0.12)
        UIBezierPath(
            ovalIn: CGRect(
                origin: CGPoint(x: rect.minX + 8, y: rect.maxY - 15),
                size: lightSize
            )
        ).fill()
        UIBezierPath(
            ovalIn: CGRect(
                origin: CGPoint(x: rect.maxX - lightSize.width - 8, y: rect.maxY - 15),
                size: lightSize
            )
        ).fill()
    }
}
#endif
