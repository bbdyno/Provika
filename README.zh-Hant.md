# Provika

[English](README.md) · [한국어](README.ko.md) · [简体中文](README.zh-Hans.md) · **繁體中文** · [日本語](README.ja.md)

**拍攝、封裝、驗證。**

Provika 是一款 iOS 應用程式，用於記錄拍攝時間、地點與原始完整性十分重要的照片和影片。它可以建立便於攜帶和匯出的證據套件，並支援無網路離線驗證。

Provika 並非只用於交通檢舉。它也適用於事件現場、設施巡檢、交付與財產狀況、現場作業，以及其他需要保留可複核拍攝記錄的情境。

> Provika 提供用於檢查檔案完整性的技術資訊，不取代司法鑑定、不判定法律證據能力，也不保證任何機構接受。拍攝、匯出或分享時，請遵守當地法規並尊重隱私。

## Provika 的運作流程

1. 拍攝照片或影片，同時記錄時間、經授權取得的位置與裝置環境資訊。
2. 保留原始媒體並產生規範化 claim。
3. 計算 SHA-256 摘要，並使用 ECDSA P-256 金鑰為證據套件簽章。
4. 將簽章 envelope 與獨立驗證所需的資料存入證據套件。
5. 無需依賴簽章時使用的 Keychain 項目，即可獨立驗證套件完整性。
6. 將驗證通過的閱讀副本匯出為安全 ZIP 與多語言 PDF 報告。

## 核心功能

| 領域 | 功能 |
| --- | --- |
| 照片與影片證據 | 帶版本的 evidence claim、原始媒體保留、確定性的套件定稿與有效性檢查 |
| 完整性 | SHA-256 摘要、ECDSA P-256 簽章、匯出的公鑰資料與離線驗證 |
| 相機 | 即時預覽、對焦和曝光、閃光燈、變焦控制、0.5 倍超廣角、方向自適應輸出與連續錄影 |
| 預錄 | 可設定的 0 / 5 / 15 / 30 秒預錄緩衝 |
| 可視環境資訊 | 可選擇將日期、時間、GPS 與應用程式/裝置資訊渲染到影片影格中 |
| 匯出 | 已驗證的 ZIP 與五種語言的人類可讀 PDF 報告 |
| 資料庫 | 瀏覽、篩選、播放、查看驗證狀態、選取、分享和刪除本機記錄 |
| 快速拍攝 | 控制中心和鎖定畫面入口、App Intents 與 ExtensionKit 鎖定畫面相機擴充功能 |
| 資料安全 | 舊錄影遷移、原始檔案不變策略、安全檔名、符號連結拒絕與原子 staging |
| 地區適配 | 同一個全球離線 Evidence Core 支援中國大陸的 claim 與介面策略，不建立中國專用證據核心 |

## 證據套件

定稿後的 v2 證據套件包含原始媒體與機器可讀的驗證記錄，例如：

```text
EvidencePackage/
  <原始媒體>
  claim.json
  signature.json
  manifest.json       # 由相應流程產生時包含
Photo Evidence Report.pdf
```

PDF 是便於閱讀的副本，本身並不是已簽章的原始證據。完整性驗證必須針對原始證據套件檔案進行。

## 支援語言

應用程式介面、權限說明、證據報告文字與 App Store 中繼資料支援：

- 繁體中文
- 簡體中文
- 英文
- 韓文
- 日文

簽章後的 Evidence Core 與語言無關。翻譯後的顯示文字不會取代已簽章的原始觀測值。

## 隱私與離線邊界

- 在使用者主動匯出或分享之前，證據媒體與套件資料保留在裝置上。
- 拍攝、雜湊、簽章、套件定稿、驗證與 ZIP 匯出均設計為無需服務連線即可完成。
- 只有獲得系統授權後才會記錄位置；原始裝置座標與顯示用轉換座標保持可區分。
- 僅當本機存在 `GoogleService-Info.plist` 時才會初始化 Firebase。發佈前應檢查實際 Release 設定與隱私權資訊清單。
- 鎖定畫面相機擴充功能運作於 Apple 受限的 ExtensionKit 環境，並使用臨時工作階段容器。

## 技術架構

| 項目 | 內容 |
| --- | --- |
| 語言 | Swift 5.9+ |
| 最低系統 | iOS 18.0 |
| 介面 | SwiftUI + UIKit 橋接 |
| 相機與媒體 | AVFoundation、Core Image |
| 儲存 | SwiftData、FileManager |
| 位置 | CoreLocation |
| 完整性 | CryptoKit、Security framework，以及可用時的 Secure Enclave |
| 快速拍攝 | App Intents、WidgetKit、LockedCameraCapture、ExtensionKit |
| 專案產生 | Tuist 4.x |

## 儲存庫結構

```text
Sources/
  App/                     應用程式入口與導覽
  Core/
    Evidence/V2/           規範化 claim、簽章 payload、finalizer、verifier
    Export/                安全 ZIP 與多語言 PDF 匯出
    Localization/          與語言無關的已確認文字策略
    LockedCapture/         鎖定畫面拍攝匯入與 handoff 策略
    Policy/                離線與地區 claim 邊界
    Storage/               模型、遷移與證據資料安全
    Workflow/              拍攝、錄影與匯出狀態機
  Features/
    Camera/                照片/影片拍攝管線與控制
    Gallery/               本機瀏覽與詳細驗證介面
    Settings/              使用者設定、金鑰與支援介面
  LockedCaptureExtension/  ExtensionKit 鎖定畫面相機體驗
  Widgets/                 快速拍攝控制項
Resources/                 資源、隱私權資訊清單、政策與字串目錄
Tests/                     證據、工作流程、多語系與發佈測試
Documentation/             設計邊界與特性說明
```

## 建置與測試

### 需求

- 包含 iOS 18 SDK 或更新版本的 Xcode
- Tuist 4.x

### 產生專案

```bash
tuist install
tuist generate --no-open
```

### 建置

```bash
xcodebuild \
  -workspace Provika.xcworkspace \
  -scheme Provika \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

### 測試

```bash
xcodebuild \
  -workspace Provika.xcworkspace \
  -scheme Provika \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

必要時請將模擬器名稱替換為本機已安裝的裝置。涉及硬體、相機行為、Secure Enclave、無線狀態或鎖定裝置環境的結論，仍需要真實裝置證據。

## 授權

Apache License 2.0。詳見 [LICENSE](LICENSE)。
