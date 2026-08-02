import Foundation

/// Locale-neutral signed Core contract for finalized Video Evidence packages.
struct VideoEvidenceClaimV2: Codable, Equatable, Sendable {
    static let currentSchemaVersion = "2.0"
    static let originalFileName = "original.mov"

    let schemaVersion: String
    let packageID: UUID
    let media: Media
    let capture: Capture
    let app: App
    let device: Device
    let finalization: Finalization
    let videoTrack: Track
    let audioTrack: Track?
    let audioIncluded: Bool
    let microphoneAuthorization: VideoMicrophoneAuthorization
    let silentRecordingDecision: VideoSilentRecordingDecision

    init(
        packageID: UUID,
        media: Media,
        capture: Capture,
        app: App,
        device: Device,
        finalization: Finalization,
        videoTrack: Track,
        audioTrack: Track?,
        audioIncluded: Bool,
        microphoneAuthorization: VideoMicrophoneAuthorization,
        silentRecordingDecision: VideoSilentRecordingDecision
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.packageID = packageID
        self.media = media
        self.capture = capture
        self.app = app
        self.device = device
        self.finalization = finalization
        self.videoTrack = videoTrack
        self.audioTrack = audioTrack
        self.audioIncluded = audioIncluded
        self.microphoneAuthorization = microphoneAuthorization
        self.silentRecordingDecision = silentRecordingDecision
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, packageID, media, capture, app, device, finalization
        case videoTrack, audioTrack, audioIncluded, microphoneAuthorization, silentRecordingDecision
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(String.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(forKey: .schemaVersion, in: container, debugDescription: "Unsupported Video Evidence schemaVersion")
        }
        let media = try container.decode(Media.self, forKey: .media)
        guard media.fileName == Self.originalFileName, media.mediaType == "video/quicktime" else {
            throw DecodingError.dataCorruptedError(forKey: .media, in: container, debugDescription: "Unsupported Video Evidence media contract")
        }
        let finalization = try container.decode(Finalization.self, forKey: .finalization)
        guard finalization.status == "completed" else {
            throw DecodingError.dataCorruptedError(forKey: .finalization, in: container, debugDescription: "Video was not finalized")
        }
        let videoTrack = try container.decode(Track.self, forKey: .videoTrack)
        guard videoTrack.kind == "video" else {
            throw DecodingError.dataCorruptedError(forKey: .videoTrack, in: container, debugDescription: "Missing video track observation")
        }
        let audioTrack = try container.decodeIfPresent(Track.self, forKey: .audioTrack)
        let audioIncluded = try container.decode(Bool.self, forKey: .audioIncluded)
        guard audioIncluded == (audioTrack != nil), audioTrack?.kind == "audio" || audioTrack == nil else {
            throw DecodingError.dataCorruptedError(forKey: .audioIncluded, in: container, debugDescription: "Audio observation is inconsistent")
        }

        self.schemaVersion = schemaVersion
        self.packageID = try container.decode(UUID.self, forKey: .packageID)
        self.media = media
        self.capture = try container.decode(Capture.self, forKey: .capture)
        self.app = try container.decode(App.self, forKey: .app)
        self.device = try container.decode(Device.self, forKey: .device)
        self.finalization = finalization
        self.videoTrack = videoTrack
        self.audioTrack = audioTrack
        self.audioIncluded = audioIncluded
        self.microphoneAuthorization = try container.decode(VideoMicrophoneAuthorization.self, forKey: .microphoneAuthorization)
        self.silentRecordingDecision = try container.decode(VideoSilentRecordingDecision.self, forKey: .silentRecordingDecision)
    }

    func replacingMediaDigest(_ digest: String, byteLength: Int) -> Self {
        .init(
            packageID: packageID,
            media: .init(fileName: media.fileName, mediaType: media.mediaType, byteLength: byteLength, sha256: digest),
            capture: capture,
            app: app,
            device: device,
            finalization: finalization,
            videoTrack: videoTrack,
            audioTrack: audioTrack,
            audioIncluded: audioIncluded,
            microphoneAuthorization: microphoneAuthorization,
            silentRecordingDecision: silentRecordingDecision
        )
    }

    func canonicalData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    var requiredTracks: [String] { audioIncluded ? ["audio", "video"] : ["video"] }

    struct Media: Codable, Equatable, Sendable {
        let fileName: String
        let mediaType: String
        let byteLength: Int
        let sha256: String
    }

    struct Capture: Codable, Equatable, Sendable {
        let deviceTimeUTC: String
        let timeSource: String

        init(deviceTimeUTC: String) {
            self.deviceTimeUTC = deviceTimeUTC
            self.timeSource = "device-clock"
        }
    }

    struct App: Codable, Equatable, Sendable {
        let name: String
        let version: String
        let build: String
    }

    struct Device: Codable, Equatable, Sendable {
        let model: String
        let systemVersion: String
    }

    struct Finalization: Codable, Equatable, Sendable {
        let status: String
        let completedAtUTC: String

        init(completedAtUTC: String) {
            self.status = "completed"
            self.completedAtUTC = completedAtUTC
        }
    }

    struct Track: Codable, Equatable, Sendable {
        let kind: String
        let codec: String
        let durationMilliseconds: Int64
        let width: Int?
        let height: Int?
        let channelCount: Int?
    }
}
