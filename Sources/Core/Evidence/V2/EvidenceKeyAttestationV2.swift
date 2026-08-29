import Foundation

/// 하드웨어 키 증명 기록.
///
/// Android Keystore 는 서명 키가 실제 보안 하드웨어(StrongBox 또는 TEE)에서 생성됐고 추출될 수
/// 없다는 사실을, 제조사 루트로 체인되는 X.509 인증서로 증명할 수 있다. iOS Secure Enclave 에는
/// 대응하는 내보내기 형식이 없으므로 iOS 파이프라인은 이 필드를 채우지 않는다.
///
/// 그럼에도 스키마에 두는 이유는 두 가지다.
/// 1. 검증기가 다른 플랫폼이 만든 패키지를 읽을 때 값을 잃지 않아야 한다.
/// 2. 영상 검증기는 클레임을 정규 재직렬화해 바이트 일치를 확인하므로, 모르는 필드가 있으면
///    재직렬화 결과가 달라져 유효한 패키지를 거부하게 된다.
///
/// 이 기록은 "키가 하드웨어에 있다"만 말한다. 촬영 내용의 진위나 법적 효력을 뜻하지 않는다.
struct EvidenceKeyAttestationV2: Codable, Equatable, Sendable {
    /// leaf 부터 root 순서의 X.509 DER base64.
    let certificates: [String]
    let format: String
    /// `strongbox` / `trusted-environment` / `software`
    let securityLevel: String

    static let expectedFormat = "android-key-attestation-x509-chain"
    static let securityLevels: Set<String> = ["strongbox", "trusted-environment", "software"]

    init(certificates: [String], securityLevel: String) {
        self.certificates = certificates
        self.format = Self.expectedFormat
        self.securityLevel = securityLevel
    }

    private enum CodingKeys: String, CodingKey {
        case certificates, format, securityLevel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let format = try container.decode(String.self, forKey: .format)
        guard format == Self.expectedFormat else {
            throw DecodingError.dataCorruptedError(
                forKey: .format,
                in: container,
                debugDescription: "Unsupported attestation format: \(format)"
            )
        }
        let securityLevel = try container.decode(String.self, forKey: .securityLevel)
        guard Self.securityLevels.contains(securityLevel) else {
            throw DecodingError.dataCorruptedError(
                forKey: .securityLevel,
                in: container,
                debugDescription: "Unsupported attestation security level: \(securityLevel)"
            )
        }

        self.certificates = try container.decode([String].self, forKey: .certificates)
        self.format = format
        self.securityLevel = securityLevel
    }
}

/// 위치 관측 출처 계약.
///
/// iOS 는 CoreLocation(`core-location-device`), Android 는 Fused Location Provider
/// (`fused-location-device`) 로 좌표를 얻는다. 증거 기록에서 관측 출처를 다른 플랫폼 이름으로
/// 적을 수는 없으므로, 컨테이너 계약과 같은 방식으로 양쪽 값을 모두 인정한다.
enum EvidenceLocationSourceContract {
    static let coreLocation = "core-location-device"
    static let fusedLocation = "fused-location-device"

    /// 이 플랫폼이 새 클레임에 기록하는 값.
    static let native = coreLocation

    static let supported: Set<String> = [coreLocation, fusedLocation]

    static func permits(_ source: String) -> Bool { supported.contains(source) }
}
