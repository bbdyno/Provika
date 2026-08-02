import Foundation

/// The report language is presentation-only. It is deliberately absent from every
/// signed claim, signature envelope, and canonicalization input.
enum EvidenceReportLanguage: String, CaseIterable, Codable {
    case korean = "ko"
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
}

struct EvidenceReportCopy: Equatable {
    let title: String
    let packageID: String
    let deviceTime: String
    let location: String
    let displayCopy: String
    let originalEvidencePackage: String
    let unsigned: String
    let derivativeGuidance: String

    static func localized(_ language: EvidenceReportLanguage) -> EvidenceReportCopy {
        switch language {
        case .korean:
            return .init(
                title: "사진 증거 읽기용 보고서",
                packageID: "패키지 ID",
                deviceTime: "기기에서 관찰된 촬영 시각",
                location: "기기에서 관찰된 촬영 위치",
                displayCopy: "이 문서는 사람이 읽기 위한 표시 사본입니다.",
                originalEvidencePackage: "EvidencePackage/의 원본 증거 패키지가 검증 대상입니다.",
                unsigned: "이 PDF 보고서는 서명되지 않았습니다.",
                derivativeGuidance: "공유·인쇄된 파생물만으로 무결성을 판단하지 말고 원본 패키지를 독립 검증하십시오."
            )
        case .english:
            return .init(
                title: "Photo Evidence Reading Report",
                packageID: "Package ID",
                deviceTime: "Capture time observed by device",
                location: "Capture location observed by device",
                displayCopy: "This document is a human-readable display copy.",
                originalEvidencePackage: "The original evidence package in EvidencePackage/ is the verification subject.",
                unsigned: "This PDF report is unsigned.",
                derivativeGuidance: "Do not infer integrity from a shared or printed derivative; independently verify the original package."
            )
        case .simplifiedChinese:
            return .init(
                title: "照片证据阅读报告",
                packageID: "证据包 ID",
                deviceTime: "设备记录的拍摄时间",
                location: "设备记录的拍摄位置",
                displayCopy: "本文档仅为便于阅读的显示副本。",
                originalEvidencePackage: "EvidencePackage/ 中的原始证据包才是验证对象。",
                unsigned: "此 PDF 报告未经签名。",
                derivativeGuidance: "请勿仅凭共享或打印的派生文件判断完整性；请独立验证原始证据包。"
            )
        case .traditionalChinese:
            return .init(
                title: "照片證據閱讀報告",
                packageID: "證據套件 ID",
                deviceTime: "裝置記錄的拍攝時間",
                location: "裝置記錄的拍攝位置",
                displayCopy: "本文件僅為方便閱讀的顯示副本。",
                originalEvidencePackage: "EvidencePackage/ 中的原始證據套件才是驗證對象。",
                unsigned: "此 PDF 報告未經簽署。",
                derivativeGuidance: "請勿僅憑分享或列印的衍生檔案判斷完整性；請獨立驗證原始證據套件。"
            )
        case .japanese:
            return .init(
                title: "写真証拠閲覧レポート",
                packageID: "パッケージID",
                deviceTime: "デバイスが記録した撮影時刻",
                location: "デバイスが記録した撮影場所",
                displayCopy: "この文書は人が読むための表示用コピーです。",
                originalEvidencePackage: "検証対象はEvidencePackage/内の元の証拠パッケージです。",
                unsigned: "このPDFレポートは署名されていません。",
                derivativeGuidance: "共有または印刷された派生物だけで完全性を判断せず、元のパッケージを独立して検証してください。"
            )
        }
    }
}
