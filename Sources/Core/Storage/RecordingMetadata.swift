import Foundation

struct RecordingMetadata: Codable {
    let id: String
    let version: String
    let app: AppInfo
    let device: DeviceInfo
    let recording: RecordingInfo
    var locationTrack: [LocationPoint]
    var integrity: IntegrityInfo?
    var userNote: String?
    var reportedAt: String?

    struct AppInfo: Codable {
        let name: String
        let version: String
        let build: String
    }

    struct DeviceInfo: Codable {
        let model: String
        let systemVersion: String
        let identifierForVendor: String?
    }

    struct RecordingInfo: Codable {
        let startedAt: String
        let endedAt: String?
        let duration: TimeInterval?
        let resolution: String
        let frameRate: Int
        let codec: String
    }

    struct LocationPoint: Codable {
        let ts: String
        let lat: Double
        let lng: Double
        let speed: Double
        let heading: Double
    }

    struct IntegrityInfo: Codable {
        let algorithm: String
        let hash: String
        let signatureAlgorithm: String?
        let signature: String?
        let publicKey: String?
    }
}

extension RecordingMetadata {
    static func create(
        id: String,
        device: DeviceInfo,
        resolution: String,
        frameRate: Int,
        codec: String,
        startedAt: Date
    ) -> RecordingMetadata {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        return RecordingMetadata(
            id: id,
            version: "1.0",
            app: AppInfo(name: "Provika", version: appVersion, build: buildNumber),
            device: device,
            recording: RecordingInfo(
                startedAt: isoFormatter.string(from: startedAt),
                endedAt: nil,
                duration: nil,
                resolution: resolution,
                frameRate: frameRate,
                codec: codec
            ),
            locationTrack: [],
            integrity: nil,
            userNote: nil,
            reportedAt: nil
        )
    }
}
