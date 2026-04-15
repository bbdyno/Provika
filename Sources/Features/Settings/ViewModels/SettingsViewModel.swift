import Foundation
import os

@Observable
final class SettingsViewModel {
    // 녹화 설정
    var videoQuality: VideoQuality {
        get { VideoQuality(rawValue: UserDefaults.standard.string(forKey: "videoQuality") ?? "") ?? .hd1080p30 }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "videoQuality") }
    }

    var codec: VideoCodec {
        get { VideoCodec(rawValue: UserDefaults.standard.string(forKey: "videoCodec") ?? "") ?? .hevc }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "videoCodec") }
    }

    var preRecordDuration: PreRecordDuration {
        get { PreRecordDuration(rawValue: UserDefaults.standard.integer(forKey: "preRecordDuration")) ?? .seconds15 }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "preRecordDuration") }
    }

    // 저장소 설정
    var autoDeletePolicy: AutoDeletePolicy {
        get { AutoDeletePolicy(rawValue: UserDefaults.standard.integer(forKey: "autoDeletePolicy")) ?? .off }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "autoDeletePolicy") }
    }

    // 오버레이 설정
    var showTimestamp: Bool {
        get { UserDefaults.standard.object(forKey: "showTimestamp") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "showTimestamp") }
    }

    var showLocation: Bool {
        get { UserDefaults.standard.object(forKey: "showLocation") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "showLocation") }
    }

    var showDeviceInfo: Bool {
        get { UserDefaults.standard.object(forKey: "showDeviceInfo") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "showDeviceInfo") }
    }

    // 보안
    var publicKeyPEM: String = ""
    var showRegenerateKeyAlert = false

    private let signatureService = SignatureService()
    private let logger = Logger(subsystem: "com.bbdyno.app.provika", category: "Settings")

    func loadPublicKey() {
        do {
            publicKeyPEM = try signatureService.publicKeyPEM()
        } catch {
            publicKeyPEM = "키를 불러올 수 없습니다"
            logger.error("공개키 로드 실패: \(error.localizedDescription)")
        }
    }

    func regenerateKey() {
        do {
            try signatureService.deleteKey()
            _ = try signatureService.getOrCreateKey()
            loadPublicKey()
            logger.info("서명 키 재생성 완료")
        } catch {
            logger.error("키 재생성 실패: \(error.localizedDescription)")
        }
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Enums

    enum VideoQuality: String, CaseIterable {
        case hd1080p30 = "1080p 30fps"
        case hd1080p60 = "1080p 60fps"
        case uhd4K30 = "4K 30fps"
    }

    enum VideoCodec: String, CaseIterable {
        case hevc = "HEVC"
        case h264 = "H.264"
    }

    enum PreRecordDuration: Int, CaseIterable {
        case off = 0
        case seconds5 = 5
        case seconds15 = 15
        case seconds30 = 30

        var displayName: String {
            switch self {
            case .off: return "Off"
            case .seconds5: return "5s"
            case .seconds15: return "15s"
            case .seconds30: return "30s"
            }
        }
    }

    enum AutoDeletePolicy: Int, CaseIterable {
        case off = 0
        case days30 = 30
        case days90 = 90

        var displayName: String {
            switch self {
            case .off: return "Off"
            case .days30: return "30일"
            case .days90: return "90일"
            }
        }
    }
}
