import XCTest
@testable import Provika

/// Android 판 Provika 와 증거 패키지를 서로 검증하기 위해 넓힌 계약을 고정한다.
///
/// 배경: Android `MediaMuxer` 는 QuickTime 컨테이너를 출력하지 못하고, 위치는 CoreLocation 이
/// 아니라 Fused Location Provider 에서 온다. 증거 기록에 출처를 다른 플랫폼 이름으로 적을 수는
/// 없으므로, 두 계약 모두 플랫폼 네이티브 값을 양쪽에서 인정하는 방식으로 넓혔다.
final class CrossPlatformEvidenceContractTests: XCTestCase {

    // MARK: - 컨테이너 계약

    func testMediaContractAcceptsBothPlatformContainers() {
        XCTAssertTrue(VideoEvidenceMediaContract.permits(fileName: "original.mov", mediaType: "video/quicktime"))
        XCTAssertTrue(VideoEvidenceMediaContract.permits(fileName: "original.mp4", mediaType: "video/mp4"))
    }

    func testMediaContractRejectsMismatchedPairs() {
        XCTAssertFalse(VideoEvidenceMediaContract.permits(fileName: "original.mp4", mediaType: "video/quicktime"))
        XCTAssertFalse(VideoEvidenceMediaContract.permits(fileName: "original.mkv", mediaType: "video/x-matroska"))
    }

    func testThisPlatformStillWritesQuickTime() {
        XCTAssertEqual(VideoEvidenceClaimV2.originalFileName, "original.mov")
        XCTAssertEqual(VideoEvidenceMediaContract.nativeMediaType, "video/quicktime")
    }

    func testVideoClaimDecodesAndroidMP4Container() throws {
        let json = """
        {"app":{"build":"1","name":"Provika","version":"1.0"},"audioIncluded":false,\
        "capture":{"deviceTimeUTC":"2026-08-29T04:20:11.008Z","timeSource":"device-clock"},\
        "device":{"model":"SM-S928N","systemVersion":"Android 15"},\
        "finalization":{"completedAtUTC":"2026-08-29T04:20:42.113Z","status":"completed"},\
        "media":{"byteLength":8192,"fileName":"original.mp4","mediaType":"video/mp4",\
        "sha256":"0000000000000000000000000000000000000000000000000000000000000000"},\
        "microphoneAuthorization":"authorized","packageID":"E4F50617-2839-4ABC-DEF0-123456789012",\
        "schemaVersion":"2.0","silentRecordingDecision":"disallow",\
        "videoTrack":{"codec":"hvc1","durationMilliseconds":31105,"height":1080,"kind":"video","width":1920}}
        """
        let claim = try JSONDecoder().decode(VideoEvidenceClaimV2.self, from: Data(json.utf8))

        XCTAssertEqual(claim.media.fileName, "original.mp4")
        XCTAssertEqual(claim.media.mediaType, "video/mp4")
    }

    func testVideoClaimRejectsUnsupportedContainer() {
        let json = """
        {"app":{"build":"1","name":"Provika","version":"1.0"},"audioIncluded":false,\
        "capture":{"deviceTimeUTC":"2026-08-29T04:20:11.008Z","timeSource":"device-clock"},\
        "device":{"model":"SM-S928N","systemVersion":"Android 15"},\
        "finalization":{"completedAtUTC":"2026-08-29T04:20:42.113Z","status":"completed"},\
        "media":{"byteLength":8192,"fileName":"original.mkv","mediaType":"video/x-matroska",\
        "sha256":"0000000000000000000000000000000000000000000000000000000000000000"},\
        "microphoneAuthorization":"authorized","packageID":"E4F50617-2839-4ABC-DEF0-123456789012",\
        "schemaVersion":"2.0","silentRecordingDecision":"disallow",\
        "videoTrack":{"codec":"hvc1","durationMilliseconds":31105,"height":1080,"kind":"video","width":1920}}
        """
        XCTAssertThrowsError(try JSONDecoder().decode(VideoEvidenceClaimV2.self, from: Data(json.utf8)))
    }

    // MARK: - 위치 출처 계약

    func testLocationSourceContractAcceptsBothPlatforms() {
        XCTAssertTrue(EvidenceLocationSourceContract.permits("core-location-device"))
        XCTAssertTrue(EvidenceLocationSourceContract.permits("fused-location-device"))
        XCTAssertFalse(EvidenceLocationSourceContract.permits("mock-provider"))
    }

    func testThisPlatformStillRecordsCoreLocation() {
        let location = PhotoEvidenceClaimV2.Location(lat: 37.5665, lng: 126.978, horizontalAccuracyMeters: 4.5)
        XCTAssertEqual(location.source, "core-location-device")
    }

    func testPhotoClaimDecodesFusedLocationSource() throws {
        let json = """
        {"schemaVersion":"2.0","packageID":"A0B1C2D3-E4F5-4678-9ABC-DEF012345678",\
        "media":{"fileName":"evidence.jpg","mediaType":"image/jpeg","pixelWidth":48,"pixelHeight":32,\
        "sha256":"0000000000000000000000000000000000000000000000000000000000000000"},\
        "capture":{"deviceTime":"2026-08-29T04:15:33.421Z","timeSource":"device-clock"},\
        "app":{"name":"Provika","version":"1.0","build":"1"},\
        "device":{"model":"SM-S928N","systemVersion":"Android 15"},\
        "location":{"lat":37.5665,"lng":126.978,"horizontalAccuracyMeters":5,\
        "source":"fused-location-device"}}
        """
        let claim = try JSONDecoder().decode(PhotoEvidenceClaimV2.self, from: Data(json.utf8))

        XCTAssertEqual(claim.location?.source, "fused-location-device")
        XCTAssertEqual(claim.location?.lat, 37.5665)
    }

    // MARK: - 키 증명 통과

    func testAttestationSurvivesCanonicalization() throws {
        let attestation = EvidenceKeyAttestationV2(
            certificates: ["TUlJQmxlYWY=", "TUlJQnJvb3Q="],
            securityLevel: "strongbox"
        )
        let claim = PhotoEvidenceClaimV2(
            packageID: UUID(uuidString: "A0B1C2D3-E4F5-4678-9ABC-DEF012345678")!,
            media: .init(fileName: "evidence.jpg", mediaType: "image/jpeg",
                         pixelWidth: 48, pixelHeight: 32, sha256: String(repeating: "0", count: 64)),
            capture: .init(deviceTime: "2026-08-29T04:15:33.421Z"),
            app: .init(name: "Provika", version: "1.0", build: "1"),
            device: .init(model: "SM-S928N", systemVersion: "Android 15"),
            attestation: attestation
        )

        let frozen = try EvidenceCoreCanonicalizationV2.frozenClaim(
            replacingMediaDigest: String(repeating: "a", count: 64),
            in: claim
        )
        XCTAssertEqual(frozen.attestation, attestation)

        // 정규 바이트를 다시 읽어도 증명서가 남아 있어야 한다. 값을 잃으면 영상 검증기의
        // 재직렬화 바이트 비교가 유효한 패키지를 거부하게 된다.
        let data = try EvidenceCoreCanonicalizationV2.canonicalClaimData(for: frozen)
        let decoded = try JSONDecoder().decode(PhotoEvidenceClaimV2.self, from: data)
        XCTAssertEqual(decoded.attestation?.securityLevel, "strongbox")
        XCTAssertEqual(decoded.attestation?.certificates.count, 2)
    }

    func testAttestationRejectsUnknownSecurityLevel() {
        let json = """
        {"certificates":["TUlJQmxlYWY="],"format":"android-key-attestation-x509-chain",\
        "securityLevel":"unverified"}
        """
        XCTAssertThrowsError(try JSONDecoder().decode(EvidenceKeyAttestationV2.self, from: Data(json.utf8)))
    }

    func testVideoClaimCarriesCaptureContext() throws {
        let claim = VideoEvidenceClaimV2(
            packageID: UUID(uuidString: "E4F50617-2839-4ABC-DEF0-123456789012")!,
            media: .init(fileName: "original.mp4", mediaType: "video/mp4",
                         byteLength: 8192, sha256: String(repeating: "0", count: 64)),
            capture: .init(deviceTimeUTC: "2026-08-29T04:20:11.008Z"),
            app: .init(name: "Provika", version: "1.0", build: "1"),
            device: .init(model: "SM-S928N", systemVersion: "Android 15"),
            finalization: .init(completedAtUTC: "2026-08-29T04:20:42.113Z"),
            videoTrack: .init(kind: "video", codec: "hvc1", durationMilliseconds: 31105,
                              width: 1920, height: 1080, channelCount: nil),
            audioTrack: nil,
            audioIncluded: false,
            microphoneAuthorization: .authorized,
            silentRecordingDecision: .disallow,
            context: .init(projectID: "project-1", projectName: "Gangnam", note: "메모")
        )

        let data = try claim.canonicalData()
        let decoded = try JSONDecoder().decode(VideoEvidenceClaimV2.self, from: data)

        XCTAssertEqual(decoded.context?.projectName, "Gangnam")
        XCTAssertEqual(decoded.context?.note, "메모")
        // 재직렬화 바이트가 같아야 영상 검증기의 정규형 검사를 통과한다.
        XCTAssertEqual(try decoded.canonicalData(), data)
    }

    func testVideoClaimRoundTripsAndroidOnlyFields() throws {
        let claim = VideoEvidenceClaimV2(
            packageID: UUID(uuidString: "E4F50617-2839-4ABC-DEF0-123456789012")!,
            media: .init(fileName: "original.mp4", mediaType: "video/mp4",
                         byteLength: 8192, sha256: String(repeating: "0", count: 64)),
            capture: .init(deviceTimeUTC: "2026-08-29T04:20:11.008Z"),
            app: .init(name: "Provika", version: "1.0", build: "1"),
            device: .init(model: "SM-S928N", systemVersion: "Android 15"),
            finalization: .init(completedAtUTC: "2026-08-29T04:20:42.113Z"),
            videoTrack: .init(kind: "video", codec: "hvc1", durationMilliseconds: 31105,
                              width: 1920, height: 1080, channelCount: nil),
            audioTrack: nil,
            audioIncluded: false,
            microphoneAuthorization: .authorized,
            silentRecordingDecision: .disallow,
            location: .init(lat: 37.5665, lng: 126.978, horizontalAccuracyMeters: 5),
            attestation: .init(certificates: ["TUlJQmxlYWY="], securityLevel: "trusted-environment")
        )

        let data = try claim.canonicalData()
        let decoded = try JSONDecoder().decode(VideoEvidenceClaimV2.self, from: data)

        XCTAssertEqual(decoded, claim)
        // 재직렬화 바이트가 같아야 영상 검증기의 정규형 검사를 통과한다.
        XCTAssertEqual(try decoded.canonicalData(), data)
    }
}
