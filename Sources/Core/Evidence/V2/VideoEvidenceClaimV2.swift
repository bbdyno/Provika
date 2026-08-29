import Foundation

/// 영상 컨테이너 계약.
///
/// iOS 는 QuickTime(`original.mov`), Android 는 MP4(`original.mp4`) 를 기록한다.
/// Android `MediaMuxer` 는 MOV 를 출력하지 못하므로 플랫폼 네이티브 컨테이너를 각각 인정한다.
/// 컨테이너 종류는 클레임에 그대로 남고 해시는 컨테이너와 무관하므로 증거력 차이는 없다.
enum VideoEvidenceMediaContract {
    static let quickTimeFileName = "original.mov"
    static let quickTimeMediaType = "video/quicktime"
    static let mp4FileName = "original.mp4"
    static let mp4MediaType = "video/mp4"

    /// 이 플랫폼이 새 패키지를 만들 때 쓰는 컨테이너.
    static let nativeFileName = quickTimeFileName
    static let nativeMediaType = quickTimeMediaType

    static let supported: [String: String] = [
        quickTimeFileName: quickTimeMediaType,
        mp4FileName: mp4MediaType
    ]

    static var supportedFileNames: Set<String> { Set(supported.keys) }

    static func permits(fileName: String, mediaType: String) -> Bool {
        supported[fileName] == mediaType
    }
}

/// Locale-neutral signed Core contract for finalized Video Evidence packages.
struct VideoEvidenceClaimV2: Codable, Equatable, Sendable {
    static let currentSchemaVersion = "2.0"
    /// 이 플랫폼이 기록하는 컨테이너 파일명. 검증은 `VideoEvidenceMediaContract` 전체를 받아들인다.
    static let originalFileName = VideoEvidenceMediaContract.nativeFileName

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
    /// 촬영 시작 시점의 위치 관측값. iOS 파이프라인은 채우지 않지만, 다른 플랫폼이 기록한 값을
    /// 정규 재직렬화에서 잃지 않도록 스키마에 둔다.
    let location: PhotoEvidenceClaimV2.Location?
    /// 하드웨어 키 증명(Android). iOS 에는 대응물이 없으나 같은 이유로 스키마에 둔다.
    let attestation: EvidenceKeyAttestationV2?

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
        silentRecordingDecision: VideoSilentRecordingDecision,
        location: PhotoEvidenceClaimV2.Location? = nil,
        attestation: EvidenceKeyAttestationV2? = nil
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
        self.location = location
        self.attestation = attestation
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, packageID, media, capture, app, device, finalization
        case videoTrack, audioTrack, audioIncluded, microphoneAuthorization, silentRecordingDecision
        case location, attestation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(String.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(forKey: .schemaVersion, in: container, debugDescription: "Unsupported Video Evidence schemaVersion")
        }
        let media = try container.decode(Media.self, forKey: .media)
        guard VideoEvidenceMediaContract.permits(fileName: media.fileName, mediaType: media.mediaType) else {
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
        self.location = try container.decodeIfPresent(PhotoEvidenceClaimV2.Location.self, forKey: .location)
        self.attestation = try container.decodeIfPresent(EvidenceKeyAttestationV2.self, forKey: .attestation)
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
            silentRecordingDecision: silentRecordingDecision,
            location: location,
            attestation: attestation
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
