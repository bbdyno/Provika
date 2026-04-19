# Provika — Claude Code 개발 프롬프트

> 이 문서는 Claude Code의 작업 지침서입니다.
> 저장소 루트에 `CLAUDE.md`로 두고, 작업 시작 시 먼저 이 문서를 읽고 단계별로 진행하세요.

---

## 0. 작업 원칙 (반드시 준수)

1. **순차 구현**: §10 "구현 순서"의 Phase 1 → 9를 순서대로 진행. 각 Phase 완료 후 빌드 성공·동작 확인 전까지 다음 Phase로 넘어가지 않음.
2. **빌드 검증**: 매 Phase 종료 시 `tuist generate && xcodebuild -workspace Provika.xcworkspace -scheme Provika -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build` 실행하여 컴파일 에러 0 확인.
3. **추측 금지**: 명세가 모호하면 코드를 작성하기 전에 사용자에게 질문.
4. **Apple 프레임워크 only**: CocoaPods, Carthage, 외부 SPM 패키지 모두 사용 금지. 단, **Tuist는 사용**(빌드 도구).
5. **언어 정책**:
   - 코드 식별자(변수·함수·타입·파일명): **영문**
   - 주석·커밋 메시지·README: **한글**
   - 사용자 노출 문자열: **반드시 TuistStrings 통해 다국어 처리** (하드코딩 금지)
6. **폴더 정책**: 저장소 루트에서 직접 작업. **`Provika/` 폴더를 새로 만들지 말 것** (저장소 자체가 Provika).
7. **커밋 단위**: 기능 단위로 의미 있는 한글 커밋 메시지 (예: `feat: 카메라 프리뷰 SwiftUI 래퍼 구현`).

---

## 1. 프로젝트 개요

### 1.1 앱 정체성
**Provika**는 교통법규 위반 영상을 촬영하여 경찰·국민신문고 공익신고에 사용할 때 **증거자료로 인정받을 수 있는 신뢰성**을 갖춘 iOS 앱이다.

일반 카메라 앱 대비 차별점:
- 프레임에 직접 burn-in된 **타임스탬프·GPS 좌표** (사후 편집 불가)
- **SHA-256 해시 + Secure Enclave 디지털 서명**으로 무결성 보장
- 메타데이터 **이중 기록** (비디오 트랙 + 사이드카 JSON)
- 녹화 **연속성 보장** (중간 일시정지 금지)
- **선녹화 버퍼** (직전 10~30초 자동 보관, 위반 순간 놓침 방지)

### 1.2 GitHub 한 줄 소개
> Tamper-proof iOS dashcam for traffic violation reporting — burn-in timestamp, GPS overlay, and SHA-256 integrity hash. Built with SwiftUI + AVFoundation + Tuist.

---

## 2. 기술 스택

| 항목 | 선택 |
|---|---|
| 언어 | Swift 5.9+ |
| 최소 OS | **iOS 18.0** (Control Widget 지원 최소 버전) |
| UI | SwiftUI (카메라 프리뷰만 `UIViewRepresentable`로 UIKit 래핑) |
| 영상 캡처 | AVFoundation (`AVCaptureSession` + `AVAssetWriter`) |
| 오버레이 합성 | Core Image (`CIFilter`, `CIContext`) |
| 위치 | CoreLocation |
| 데이터 저장 | SwiftData (인덱싱) + FileManager (실제 파일) |
| 보안 | CryptoKit (SHA-256), Security framework (Secure Enclave) |
| 빌드 도구 | **Tuist 4.x** |
| 다국어 | **TuistStrings (ResourceSynthesizers)** |
| 테스트 | XCTest |
| 아키텍처 | MVVM + Service Layer |

---

## 3. Tuist 설정

### 3.1 Tuist 버전 및 설치
- 사용자가 이미 Tuist 설치되어 있다고 가정. 설치 안 되어 있으면 안내:
  ```bash
  curl -Ls https://install.tuist.io | bash
  ```
- 작업 시작 전 `tuist version` 실행하여 4.x 확인. 3.x이면 사용자에게 업그레이드 요청.

### 3.2 `Tuist/Config.swift`
```swift
import ProjectDescription

let config = Config(
    compatibleXcodeVersions: .upToNextMajor("16.0"),
    swiftVersion: "5.9"
)
```

### 3.3 `Project.swift` (저장소 루트)

```swift
import ProjectDescription

let project = Project(
    name: "Provika",
    organizationName: "Provika",
    options: .options(
        defaultKnownRegions: ["en", "ko"],
        developmentRegion: "en"
    ),
    settings: .settings(
        base: [
            "DEVELOPMENT_TEAM": "", // 사용자가 채워야 함
            "MARKETING_VERSION": "1.0.0",
            "CURRENT_PROJECT_VERSION": "1",
            "IPHONEOS_DEPLOYMENT_TARGET": "18.0",
            "SWIFT_VERSION": "5.9",
            "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
            "GENERATE_INFOPLIST_FILE": "YES"
        ],
        configurations: [
            .debug(name: "Debug"),
            .release(name: "Release")
        ]
    ),
    targets: [
        .target(
            name: "Provika",
            destinations: .iOS,
            product: .app,
            bundleId: "com.provika.app",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Provika",
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "UILaunchScreen": [:],
                "UIApplicationSceneManifest": [
                    "UIApplicationSupportsMultipleScenes": false
                ],
                "UISupportedInterfaceOrientations": [
                    "UIInterfaceOrientationPortrait"
                ],
                "UIBackgroundModes": ["audio"], // 백그라운드 녹화 지속용
                "NSCameraUsageDescription": "$(LOCALIZED:NSCameraUsageDescription)",
                "NSMicrophoneUsageDescription": "$(LOCALIZED:NSMicrophoneUsageDescription)",
                "NSLocationWhenInUseUsageDescription": "$(LOCALIZED:NSLocationWhenInUseUsageDescription)",
                "NSPhotoLibraryAddUsageDescription": "$(LOCALIZED:NSPhotoLibraryAddUsageDescription)"
            ]),
            sources: ["Sources/**"],
            resources: [
                "Resources/**"
            ],
            dependencies: []
        ),
        .target(
            name: "ProvikaTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.provika.app.tests",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .default,
            sources: ["Tests/**"],
            dependencies: [.target(name: "Provika")]
        )
    ],
    resourceSynthesizers: [
        .strings(),  // TuistStrings: Localizable.strings → Strings.swift 자동 생성
        .assets(),   // Assets.xcassets → Asset.swift 자동 생성
        .fonts()     // (필요 시)
    ]
)
```

> **중요 — Info.plist 권한 설명 다국어**
> `$(LOCALIZED:KEY)` 표기는 placeholder. 실제로는 `Resources/en.lproj/InfoPlist.strings`와 `Resources/ko.lproj/InfoPlist.strings`에 권한 설명을 정의하면 자동으로 다국어 처리됨. §6 참조.

---

## 4. 폴더 구조 (저장소 루트 기준)

```
.
├── CLAUDE.md                    ← 이 문서
├── README.md                    ← 한글 README (Phase 9)
├── .gitignore                   ← Tuist Derived/, *.xcworkspace 등 제외
├── Tuist/
│   └── Config.swift
├── Project.swift
├── Sources/
│   ├── App/
│   │   ├── ProvikaApp.swift            # @main
│   │   └── RootView.swift              # 탭 네비게이션
│   ├── Features/
│   │   ├── Camera/
│   │   │   ├── Views/
│   │   │   │   ├── CameraView.swift           # SwiftUI 메인
│   │   │   │   ├── CameraPreviewView.swift    # UIViewRepresentable
│   │   │   │   ├── CameraControlsView.swift   # 녹화 버튼·줌·플래시
│   │   │   │   └── RecordingIndicatorView.swift
│   │   │   ├── ViewModels/
│   │   │   │   └── CameraViewModel.swift
│   │   │   └── Services/
│   │   │       ├── CaptureService.swift       # AVCaptureSession 관리
│   │   │       ├── VideoWriter.swift          # AVAssetWriter 래핑
│   │   │       ├── OverlayRenderer.swift      # CIFilter burn-in
│   │   │       └── PreRecordBuffer.swift      # 링버퍼
│   │   ├── Gallery/
│   │   │   ├── Views/
│   │   │   │   ├── GalleryView.swift          # 날짜 캘린더 + 그리드
│   │   │   │   ├── DateFolderView.swift
│   │   │   │   ├── VideoThumbnailView.swift
│   │   │   │   └── VideoDetailView.swift      # 재생·해시·메타 표시
│   │   │   └── ViewModels/
│   │   │       └── GalleryViewModel.swift
│   │   └── Settings/
│   │       ├── Views/
│   │       │   └── SettingsView.swift
│   │       └── ViewModels/
│   │           └── SettingsViewModel.swift
│   ├── Core/
│   │   ├── Location/
│   │   │   └── LocationManager.swift          # CLLocationManager + Combine
│   │   ├── Storage/
│   │   │   ├── FileStorage.swift              # 디렉토리 구조 관리
│   │   │   ├── RecordingMetadata.swift        # JSON 사이드카 모델
│   │   │   └── Models/
│   │   │       └── Recording.swift            # SwiftData @Model
│   │   ├── Security/
│   │   │   ├── HashCalculator.swift           # SHA-256
│   │   │   └── SignatureService.swift         # Secure Enclave
│   │   ├── DI/
│   │   │   └── AppEnvironment.swift           # 의존성 주입 컨테이너
│   │   └── Extensions/
│   │       ├── Date+Format.swift
│   │       ├── CMTime+Helpers.swift
│   │       └── CIImage+Overlay.swift
│   └── Resources/
│       ├── Assets.xcassets/
│       │   ├── AppIcon.appiconset/
│       │   └── AccentColor.colorset/
│       ├── en.lproj/
│       │   ├── Localizable.strings
│       │   └── InfoPlist.strings
│       └── ko.lproj/
│           ├── Localizable.strings
│           └── InfoPlist.strings
└── Tests/
    ├── HashCalculatorTests.swift
    ├── OverlayRendererTests.swift
    └── FileStorageTests.swift
```

> **Tuist Derived 폴더는 자동 생성**되며 `.gitignore`에 추가. 사용자가 수정할 필요 없음.

### 4.1 `.gitignore` (필수 항목)

```
# Xcode
build/
DerivedData/
*.xcuserdata/
*.xcworkspace
*.xcodeproj

# Tuist
**/Derived/**
.tuist-version
.build/

# macOS
.DS_Store

# Swift
*.swp
.swiftpm/

# Secrets
*.p12
*.mobileprovision
ExportOptions.plist
```

> Xcode 프로젝트 파일은 Tuist가 매번 생성하므로 git에 포함하지 않음.

---

## 5. 핵심 기능 상세 명세

### 5.1 카메라 캡처 (`CaptureService` + `VideoWriter`)

#### 5.1.1 세션 구성
- `AVCaptureSession` 생성, preset 동적 선택:
  - 기본: `.hd1920x1080` (1080p 30fps)
  - 고화질 옵션: `.hd4K3840x2160` (4K 30fps, 사용자 설정에서 선택)
- 입력:
  - 비디오: `.builtInWideAngleCamera` (후면)
  - 오디오: `AVCaptureDevice.default(for: .audio)`
- 출력:
  - **`AVCaptureVideoDataOutput`** (프레임 가공 위함, MovieFileOutput 사용 안 함)
  - **`AVCaptureAudioDataOutput`**
- 안정화: `AVCaptureConnection.preferredVideoStabilizationMode = .cinematic` (지원 시)

#### 5.1.2 자동 포커스·노출
- `device.focusMode = .continuousAutoFocus`
- `device.exposureMode = .continuousAutoExposure`
- 사용자 탭 시 해당 좌표 기준 일회 포커스/노출 (1초 후 다시 continuous로 복귀)

#### 5.1.3 핀치 줌
- `UIPinchGestureRecognizer`로 스케일 변화 감지
- `device.videoZoomFactor`를 `device.minAvailableVideoZoomFactor` ~ `device.maxAvailableVideoZoomFactor` 범위로 매핑
- 변경 시 부드러운 ramp 적용: `device.ramp(toVideoZoomFactor:withRate:)`

#### 5.1.4 VideoWriter 동작
- `AVAssetWriter` (`.mov`, AVVideoCodecType.hevc 또는 h264 사용자 선택)
- 비디오 입력: `AVAssetWriterInput(mediaType: .video, outputSettings: ...)`
  - `AVAssetWriterInputPixelBufferAdaptor`로 가공된 픽셀버퍼 직접 주입
- 오디오 입력: `AVAssetWriterInput(mediaType: .audio, ...)`
- `expectsMediaDataInRealTime = true`
- 매 프레임마다:
  1. `CaptureService`에서 raw `CMSampleBuffer` 수신
  2. `OverlayRenderer.render(sampleBuffer:)` 호출하여 burn-in
  3. 결과 `CVPixelBuffer`를 `pixelBufferAdaptor.append(...)` 로 기록

### 5.2 오버레이 burn-in (`OverlayRenderer`)

#### 5.2.1 표시 정보
- **좌상단**: `yyyy-MM-dd HH:mm:ss.SSS` (밀리초)
- **우상단**: GPS 좌표 (`lat: 37.5665, lng: 126.9780`) + 속도 (`km/h`) + 방위 (°)
- **하단 중앙**: `Provika v1.0.0 · iPhone 15 Pro · SN:A1B2C3`
- 폰트: `Menlo-Bold` (모노스페이스, 가독성)
- 크기: 영상 높이의 3% (1080p 기준 ~32pt)
- 색: 흰색, 검은색 outline 1pt (역광 가독성)

#### 5.2.2 구현
```swift
final class OverlayRenderer {
    private let ciContext: CIContext
    private let dateFormatter: DateFormatter

    func render(
        sampleBuffer: CMSampleBuffer,
        location: CLLocation?,
        deviceInfo: DeviceInfo
    ) -> CVPixelBuffer? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let baseImage = CIImage(cvPixelBuffer: pixelBuffer)

        // 1. 텍스트 → CIImage 변환 (CITextImageGenerator 또는 CGContext 렌더링 후 CIImage)
        let topLeftText = makeText(timestampString())
        let topRightText = makeText(locationString(location))
        let bottomText = makeText(footerString(deviceInfo))

        // 2. 합성
        var composited = baseImage
        composited = topLeftText.composited(over: composited)
        composited = topRightText.composited(over: composited)
        composited = bottomText.composited(over: composited)

        // 3. 결과를 새 CVPixelBuffer로 렌더링
        var output: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault,
                            CVPixelBufferGetWidth(pixelBuffer),
                            CVPixelBufferGetHeight(pixelBuffer),
                            CVPixelBufferGetPixelFormatType(pixelBuffer),
                            nil, &output)
        if let output {
            ciContext.render(composited, to: output)
        }
        return output
    }
}
```

> **성능 주의**: 매 프레임 텍스트 렌더링은 비싸므로, 같은 초 내에서는 timestamp 텍스트 캐싱. GPS는 1Hz로 업데이트.

### 5.3 위치 (`LocationManager`)

- `CLLocationManager` 싱글턴 또는 EnvironmentObject
- 권한: `requestWhenInUseAuthorization`
- `desiredAccuracy = kCLLocationAccuracyBest`
- `distanceFilter = 1` (1m마다 업데이트)
- 녹화 중에는 `allowsBackgroundLocationUpdates = true` (UIBackgroundModes에 location 추가 필요)
- `@Published var currentLocation: CLLocation?`로 노출

### 5.4 선녹화 버퍼 (`PreRecordBuffer`)

- 메모리 링버퍼: 최근 N초 (기본 15초, 설정에서 5/15/30초 선택)
- `CMSampleBuffer` 큐 유지, 시간 초과 시 가장 오래된 것 drop
- 녹화 시작 시 버퍼의 모든 샘플을 VideoWriter에 먼저 주입한 뒤 실시간 캡처 이어서 진행
- 메모리 사용량 모니터링: 4K 30fps 30초 = 약 1GB 위험. 1080p 기준으로 제한 권장.

### 5.5 무결성 (`HashCalculator` + `SignatureService`)

#### 5.5.1 SHA-256 해시
```swift
import CryptoKit

enum HashCalculator {
    static func sha256(of fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: 1024 * 1024) // 1MB chunks
            if chunk.isEmpty { return false }
            hasher.update(data: chunk)
            return true
        }) {}
        return hasher.finalize().compactMap { String(format: "%02x", $0) }.joined()
    }
}
```

#### 5.5.2 Secure Enclave 서명
- 앱 최초 실행 시 Secure Enclave에 ECDSA P-256 키 생성, Keychain에 저장
- 녹화 종료 시 해시값을 서명하고 사이드카 JSON에 첨부
- 공개키도 JSON에 포함하여 검증 가능하게 함

```swift
import Security

final class SignatureService {
    private let keyTag = "com.provika.signing.key"

    func getOrCreateKey() throws -> SecKey { /* Secure Enclave 키 조회/생성 */ }
    func sign(data: Data) throws -> Data { /* ECDSA 서명 */ }
    func publicKeyPEM() throws -> String { /* 공개키 export */ }
}
```

### 5.6 저장소 구조 (`FileStorage`)

```
Documents/
├── Recordings/
│   ├── 2026-04-15/
│   │   ├── 20260415_143022_001.mov           # 영상
│   │   └── 20260415_143022_001.json          # 메타데이터
│   └── 2026-04-16/
└── Index.sqlite                                # SwiftData
```

#### 5.6.1 사이드카 JSON 스키마
```json
{
  "id": "20260415_143022_001",
  "version": "1.0",
  "app": { "name": "Provika", "version": "1.0.0", "build": "1" },
  "device": {
    "model": "iPhone 15 Pro",
    "systemVersion": "iOS 17.4",
    "identifierForVendor": "..."
  },
  "recording": {
    "startedAt": "2026-04-15T14:30:22.123+09:00",
    "endedAt": "2026-04-15T14:31:45.456+09:00",
    "duration": 83.333,
    "resolution": "1920x1080",
    "frameRate": 30,
    "codec": "hevc"
  },
  "locationTrack": [
    { "ts": "2026-04-15T14:30:22.500Z", "lat": 37.5665, "lng": 126.9780, "speed": 12.3, "heading": 89.0 }
  ],
  "integrity": {
    "algorithm": "SHA-256",
    "hash": "abc123...",
    "signatureAlgorithm": "ECDSA-P256-SHA256",
    "signature": "base64...",
    "publicKey": "-----BEGIN PUBLIC KEY-----..."
  },
  "userNote": null,
  "reportedAt": null
}
```

### 5.7 SwiftData 모델 (`Recording`)

```swift
import SwiftData
import CoreLocation

@Model
final class Recording {
    @Attribute(.unique) var id: String
    var createdAt: Date
    var duration: TimeInterval
    var fileURL: URL              // mov 파일 경로
    var sidecarURL: URL           // json 경로
    var fileHash: String
    var startLatitude: Double?
    var startLongitude: Double?
    var endLatitude: Double?
    var endLongitude: Double?
    var userNote: String?
    var isReported: Bool
    var reportedAt: Date?
    var thumbnailData: Data?      // 갤러리용 썸네일

    init(...) { ... }
}
```

### 5.8 Gallery UI

- 메인: `NavigationStack` 안에 `GalleryView`
- 상단: 월간 캘린더 (녹화 있는 날짜에 dot 표시)
- 하단: 선택 날짜의 영상 리스트 (썸네일 그리드, 2열)
- 각 항목 탭 → `VideoDetailView`:
  - `AVPlayerLayer`로 재생
  - 메타데이터 카드 (시각, 위치, 해시, 서명 검증 상태)
  - 액션 버튼: 공유 (mov + json zip), 신고 완료 표시, 삭제

### 5.9 Settings

- 영상 품질 (1080p 30/60fps, 4K 30fps)
- 코덱 (HEVC / H.264)
- 선녹화 버퍼 길이 (off / 5초 / 15초 / 30초)
- 자동 삭제 (off / 30일 / 90일 미신고분)
- 오버레이 표시 항목 토글 (시각/GPS/기기정보)
- 언어 (시스템 따름 / English / 한국어)
- 공개키 보기·복사 (검증용)
- 서명 키 재생성 (경고 후)

---

## 6. 다국어 처리 (TuistStrings)

### 6.1 원리
- Tuist의 `resourceSynthesizers: [.strings()]`가 `*.lproj/Localizable.strings`를 스캔하여 **`Strings.swift`** 파일을 자동 생성
- 생성 파일은 `Derived/Sources/Strings+Provika.swift` 등에 위치
- 코드에서 `L10n.Camera.recordButton` 형태로 type-safe 접근

### 6.2 영문 키 정책
- 키는 **dot-separated namespace**: `camera.record.start`, `gallery.empty.title`
- 모든 사용자 노출 텍스트는 키로 관리. **하드코딩 금지**.

### 6.3 `Resources/en.lproj/Localizable.strings`

```
/* Common */
"common.ok" = "OK";
"common.cancel" = "Cancel";
"common.delete" = "Delete";
"common.share" = "Share";
"common.save" = "Save";

/* Tabs */
"tab.camera" = "Camera";
"tab.gallery" = "Gallery";
"tab.settings" = "Settings";

/* Camera */
"camera.record.start" = "Start Recording";
"camera.record.stop" = "Stop Recording";
"camera.preRecord.indicator" = "Pre-recording %d s";
"camera.permission.denied.title" = "Camera Access Required";
"camera.permission.denied.message" = "Provika needs camera access to record evidence videos. Please enable it in Settings.";
"camera.zoom.label" = "%.1fx";

/* Gallery */
"gallery.title" = "Recordings";
"gallery.empty.title" = "No recordings yet";
"gallery.empty.message" = "Recorded videos will appear here, organized by date.";
"gallery.detail.hash" = "Integrity Hash (SHA-256)";
"gallery.detail.signature.valid" = "Signature Verified ✓";
"gallery.detail.signature.invalid" = "Signature Invalid ✗";
"gallery.detail.markReported" = "Mark as Reported";
"gallery.detail.delete.confirm" = "Delete this recording? This cannot be undone.";

/* Settings */
"settings.title" = "Settings";
"settings.section.recording" = "Recording";
"settings.quality" = "Video Quality";
"settings.codec" = "Codec";
"settings.preRecord" = "Pre-recording Buffer";
"settings.section.storage" = "Storage";
"settings.autoDelete" = "Auto-delete";
"settings.section.overlay" = "Overlay";
"settings.overlay.timestamp" = "Show Timestamp";
"settings.overlay.location" = "Show GPS";
"settings.overlay.device" = "Show Device Info";
"settings.section.security" = "Security";
"settings.publicKey.show" = "View Public Key";
"settings.signingKey.regenerate" = "Regenerate Signing Key";
"settings.section.about" = "About";
"settings.version" = "Version";
```

### 6.4 `Resources/ko.lproj/Localizable.strings`

```
/* 공통 */
"common.ok" = "확인";
"common.cancel" = "취소";
"common.delete" = "삭제";
"common.share" = "공유";
"common.save" = "저장";

/* 탭 */
"tab.camera" = "카메라";
"tab.gallery" = "갤러리";
"tab.settings" = "설정";

/* 카메라 */
"camera.record.start" = "녹화 시작";
"camera.record.stop" = "녹화 종료";
"camera.preRecord.indicator" = "선녹화 %d초";
"camera.permission.denied.title" = "카메라 권한 필요";
"camera.permission.denied.message" = "Provika는 증거 영상 녹화를 위해 카메라 접근이 필요합니다. 설정에서 허용해주세요.";
"camera.zoom.label" = "%.1f배";

/* 갤러리 */
"gallery.title" = "녹화 영상";
"gallery.empty.title" = "녹화된 영상이 없습니다";
"gallery.empty.message" = "녹화한 영상이 날짜별로 정리되어 표시됩니다.";
"gallery.detail.hash" = "무결성 해시 (SHA-256)";
"gallery.detail.signature.valid" = "서명 검증됨 ✓";
"gallery.detail.signature.invalid" = "서명 무효 ✗";
"gallery.detail.markReported" = "신고 완료로 표시";
"gallery.detail.delete.confirm" = "이 영상을 삭제하시겠습니까? 되돌릴 수 없습니다.";

/* 설정 */
"settings.title" = "설정";
"settings.section.recording" = "녹화";
"settings.quality" = "영상 품질";
"settings.codec" = "코덱";
"settings.preRecord" = "선녹화 버퍼";
"settings.section.storage" = "저장소";
"settings.autoDelete" = "자동 삭제";
"settings.section.overlay" = "오버레이";
"settings.overlay.timestamp" = "시간 표시";
"settings.overlay.location" = "GPS 표시";
"settings.overlay.device" = "기기 정보 표시";
"settings.section.security" = "보안";
"settings.publicKey.show" = "공개키 보기";
"settings.signingKey.regenerate" = "서명 키 재생성";
"settings.section.about" = "정보";
"settings.version" = "버전";
```

### 6.5 `Resources/en.lproj/InfoPlist.strings`

```
"NSCameraUsageDescription" = "Provika uses the camera to record traffic violation evidence videos.";
"NSMicrophoneUsageDescription" = "Provika records audio for evidence integrity.";
"NSLocationWhenInUseUsageDescription" = "Provika records GPS coordinates for evidence credibility.";
"NSPhotoLibraryAddUsageDescription" = "Provika can save recorded videos to your photo library.";
```

### 6.6 `Resources/ko.lproj/InfoPlist.strings`

```
"NSCameraUsageDescription" = "Provika는 교통위반 증거 영상 녹화를 위해 카메라를 사용합니다.";
"NSMicrophoneUsageDescription" = "Provika는 증거 무결성을 위해 음성을 함께 녹음합니다.";
"NSLocationWhenInUseUsageDescription" = "Provika는 증거 신뢰성을 위해 GPS 좌표를 기록합니다.";
"NSPhotoLibraryAddUsageDescription" = "Provika가 녹화한 영상을 사진 보관함에 저장할 수 있습니다.";
```

### 6.7 사용 예시

```swift
import SwiftUI

struct CameraControlsView: View {
    let isRecording: Bool

    var body: some View {
        Button(isRecording ? L10n.Camera.Record.stop : L10n.Camera.Record.start) {
            // ...
        }
    }
}
```

> Tuist가 자동 생성하는 `L10n` 네임스페이스는 SwiftGen 규칙을 따름.
> 처음 `tuist generate` 시 `Derived/Sources/`에 생성됨.

---

## 7. UI/UX 가이드라인 (블랙박스 컨셉)

### 7.1 디자인 방향
- **다크 모드 우선** (블랙박스 인터페이스 느낌)
- **고대비**: 배경 #0A0A0A, 액센트 #FF3B30 (녹화 빨강), 텍스트 #FFFFFF
- **모노스페이스 폰트**: 시각·해시 등 데이터 표시는 `.system(.body, design: .monospaced)`
- **최소 조작**: 카메라 화면은 큰 녹화 버튼 + 줌 슬라이더만. 운전 중 조작 가능해야 함.
- **녹화 중 시각 피드백**: 화면 외곽 빨간 테두리 펄스 + 우상단 ●REC + 경과 시간

### 7.2 카메라 화면 레이아웃

```
┌─────────────────────────────┐
│ ●REC 00:01:23   ⚙ 설정       │  ← 상단 오버레이
│                              │
│                              │
│      [카메라 프리뷰]          │
│                              │
│                              │
│   1.0x  [ 줌 슬라이더 ]  5x  │  ← 하단 컨트롤
│                              │
│      ●  ← 큰 녹화 버튼        │
│                              │
│  📁 갤러리        🔦 플래시   │
└─────────────────────────────┘
```

### 7.3 접근성
- VoiceOver 라벨 모두 다국어 지원
- Dynamic Type 대응 (텍스트 크기 조정)
- 녹화 시작/종료 시 햅틱 피드백 (`UIImpactFeedbackGenerator`)

---

## 8. 보안·심사 대비

### 8.1 App Store 심사
- `Info.plist` 권한 설명에 "교통법규 위반 신고용 증거 영상 녹화" 명시 (위에 다국어로 작성됨)
- 백그라운드 녹화 사유 설명: 운전 중 화면이 잠겨도 녹화 지속 필요
- 개인정보처리방침 URL 등록 (Settings 화면에서 링크)
- 4+ 등급 (음향 자체는 일반)

### 8.2 데이터 처리
- **모든 데이터 로컬 저장** (서버 업로드 없음)
- 사용자가 명시적으로 공유할 때만 외부 전송 (ShareSheet)
- 자동 클라우드 백업 안 함 (iCloud Documents 비활성)

---

## 9. 빌드 및 검증 명령

### 9.1 초기 셋업
```bash
# 프로젝트 생성
tuist generate

# Xcode 열기 (필요 시)
open Provika.xcworkspace
```

### 9.2 빌드 확인
```bash
xcodebuild \
  -workspace Provika.xcworkspace \
  -scheme Provika \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' \
  clean build
```

### 9.3 테스트 실행
```bash
xcodebuild \
  -workspace Provika.xcworkspace \
  -scheme Provika \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' \
  test
```

### 9.4 클린
```bash
tuist clean
rm -rf Derived/
```

---

## 10. 구현 순서 (Phase 1 → 9)

각 Phase는 **빌드 성공 + 동작 확인 후** 다음으로 진행. 각 Phase 종료 시 한글 커밋.

### Phase 1: 프로젝트 부트스트랩
- [ ] `.gitignore` 작성
- [ ] `Tuist/Config.swift` 작성
- [ ] `Project.swift` 작성 (위 §3.3 그대로)
- [ ] 빈 폴더 구조 생성 (`Sources/App`, `Sources/Features/...`, `Resources/`)
- [ ] `Sources/App/ProvikaApp.swift` 최소 SwiftUI 앱
- [ ] `Resources/{en,ko}.lproj/Localizable.strings` 빈 파일
- [ ] `Resources/{en,ko}.lproj/InfoPlist.strings` 권한 4종 (§6.5, 6.6)
- [ ] `Resources/Assets.xcassets/AppIcon.appiconset` 플레이스홀더
- [ ] `tuist generate` 성공 확인
- [ ] 시뮬레이터 빌드 성공, 빈 화면 표시
- 커밋: `chore: Tuist 프로젝트 초기 구성`

### Phase 2: 다국어 시스템 + 탭 네비게이션
- [ ] `Localizable.strings`에 §6.3, 6.4 전체 키 입력
- [ ] `tuist generate` → `L10n` 자동 생성 확인
- [ ] `RootView.swift`에 TabView (Camera / Gallery / Settings) 3개 탭
- [ ] 각 탭 placeholder 화면에 다국어 라벨 표시 확인
- [ ] 시뮬레이터 언어를 한국어/영어로 바꿔가며 라벨 변경 확인
- 커밋: `feat: 다국어 시스템 및 탭 네비게이션 구현`

### Phase 3: 위치 + 권한
- [ ] `LocationManager` 구현 (`@Observable` 클래스)
- [ ] `AppEnvironment`에 주입
- [ ] 권한 요청 트리거 (앱 첫 실행 시)
- [ ] 시뮬레이터 시뮬레이션 위치로 좌표 수신 확인 (콘솔 로그)
- 커밋: `feat: 위치 서비스 및 권한 처리`

### Phase 4: 카메라 프리뷰 (녹화 X)
- [ ] `CaptureService` 기본 세션 구성 (입력만, 출력 X)
- [ ] `CameraPreviewView`(`UIViewRepresentable`)로 `AVCaptureVideoPreviewLayer` 표시
- [ ] `CameraView`에서 프리뷰 + 줌 핀치 제스처 + 탭 포커스
- [ ] 시뮬레이터에서는 검은 화면 정상 (실제 기기에서 테스트 권장)
- 커밋: `feat: 카메라 프리뷰 및 줌·포커스 제어`

### Phase 5: 영상 녹화 + 오버레이 burn-in
- [ ] `OverlayRenderer` 구현 (시각만 먼저)
- [ ] `VideoWriter` 구현
- [ ] `CaptureService`에 `AVCaptureVideoDataOutput` 추가, 프레임을 `OverlayRenderer` → `VideoWriter`로 파이프
- [ ] 녹화 버튼으로 시작/종료, 결과를 `Documents/Recordings/yyyy-MM-dd/`에 저장
- [ ] 저장된 mov를 사진 앱에서 재생하여 burn-in 확인
- [ ] GPS·기기정보 오버레이 추가
- 커밋: `feat: 영상 녹화 및 타임스탬프·GPS burn-in`

### Phase 6: 무결성 (해시 + 서명) + 사이드카 JSON
- [ ] `HashCalculator.sha256(of:)` 구현 + 단위 테스트
- [ ] `SignatureService` Secure Enclave 키 생성/저장/서명 구현
- [ ] 녹화 종료 직후 해시 계산 → 서명 → JSON 저장
- [ ] JSON 스키마 (§5.6.1) 정확히 일치
- [ ] 단위 테스트: 동일 파일 → 동일 해시, 1바이트 변경 → 다른 해시
- 커밋: `feat: SHA-256 해시 및 Secure Enclave 서명`

### Phase 7: SwiftData 인덱싱 + 갤러리
- [ ] `Recording` SwiftData 모델 정의
- [ ] 녹화 종료 시 Recording 인스턴스 생성·저장
- [ ] `GalleryView` 캘린더 + 날짜별 그리드 구현
- [ ] `VideoDetailView` 재생 + 메타데이터 표시
- [ ] 공유·신고완료·삭제 액션
- 커밋: `feat: SwiftData 갤러리 및 영상 상세 화면`

### Phase 8: 선녹화 버퍼 + 설정 화면
- [ ] `PreRecordBuffer` 구현 (메모리 링버퍼)
- [ ] 녹화 시작 시 버퍼 prepend
- [ ] `SettingsView` 모든 옵션 (§5.9) UserDefaults 또는 SwiftData에 저장
- [ ] 공개키 보기 화면 (복사 가능)
- 커밋: `feat: 선녹화 버퍼 및 설정 화면`

### Phase 9: 마무리
- [ ] README.md 작성 (한글, 스크린샷·기능·빌드 방법)
- [ ] LICENSE (MIT 추천)
- [ ] App Icon 디자인 (검은 배경 + 흰 카메라 아이콘 + 빨간 점)
- [ ] 접근성 라벨 점검
- [ ] 햅틱 피드백 추가
- [ ] 모든 Phase 단위 테스트 통과 확인
- 커밋: `docs: README 및 라이선스 추가`

### Phase 10: 잠금화면/제어 센터/액션 버튼 원터치 녹화 (iOS 18+)

**목적**: 위반 순간을 놓치지 않도록 앱을 열지 않고도 녹화를 시작할 수 있게 한다.

#### 10.1 구조
- 새 타겟 `ProvikaWidgets` (appExtension) — Widget Extension 번들
- 공유 코드는 `Sources/Shared/`에 두고 앱·위젯 양쪽 타겟에 include
- 위젯 리소스는 `Resources/Widgets/`에 두어 앱 리소스와 분리

```
Sources/
├── Shared/
│   ├── Intents/
│   │   └── StartRecordingIntent.swift   # AppIntent, openAppWhenRun=true
│   └── Launch/
│       └── PendingLaunchAction.swift    # @Observable 싱글턴, 앱이 관찰
└── Widgets/
    ├── ProvikaWidgetBundle.swift        # @main WidgetBundle
    └── Controls/
        └── LaunchCameraControlWidget.swift   # ControlWidget
Resources/
└── Widgets/
    ├── en.lproj/Localizable.strings
    └── ko.lproj/Localizable.strings
```

#### 10.2 동작 흐름
1. 사용자가 제어 센터/잠금화면/액션 버튼에 배치된 Control Widget 탭
2. 시스템이 `StartRecordingIntent`를 invoke → `openAppWhenRun=true`이므로 앱을 포그라운드로
3. 인텐트의 `perform()`이 앱 프로세스에서 실행 → `PendingLaunchAction.shared.shouldStartRecording = true`
4. `RootView`가 플래그 변화 감지 → 카메라 탭으로 전환
5. `CameraView`가 카메라 세션 준비 상태를 확인 → 400ms 대기 후 `toggleRecording()` 호출 → 플래그 리셋

#### 10.3 구현 체크리스트
- [x] Project.swift에 `ProvikaWidgets` appExtension 타겟 추가
- [x] `StartRecordingIntent` (shared) — `openAppWhenRun = true`
- [x] `PendingLaunchAction` @Observable 싱글턴 (shared)
- [x] `LaunchCameraControlWidget` (ControlWidget, `ControlWidgetButton(action: StartRecordingIntent())`)
- [x] `ProvikaWidgetBundle` — `@main WidgetBundle`
- [x] 위젯 번들용 `Resources/Widgets/{en,ko}.lproj/Localizable.strings` — `widget.launchCamera.*`, `intent.startRecording.*` 키
- [x] 앱 번들에도 `intent.startRecording.*` 키 추가 (Shortcuts/Siri 표시용)
- [x] `ProvikaApp`에 `PendingLaunchAction.shared` 환경 주입
- [x] `RootView`가 플래그 감지 시 카메라 탭으로 전환
- [x] `CameraView`가 pending 플래그 소비하여 자동 녹화 시작
- [ ] 실기기(iOS 18+)에서 제어 센터/잠금화면/액션 버튼 배치 후 녹화 시작 확인

#### 10.4 주의사항
- Widget Extension 프로세스는 AVCaptureSession을 구동할 수 없음 — 반드시 `openAppWhenRun = true`로 앱을 먼저 깨움
- `StartRecordingIntent`는 shared 파일로 양쪽 타겟에 같은 타입명으로 컴파일됨 (시스템이 타입명 기준 라우팅)
- 향후 확장: 토글 지원(App Groups + 상태 동기화), Live Activity로 녹화 중 표시, `OpenIntent` 변형으로 특정 모드 진입

- 커밋: `feat: iOS 18 Control Widget으로 잠금화면/제어 센터/액션 버튼 원터치 녹화 구현`

---

## 11. 사용자 확인 필요 사항 (Claude Code가 작업 시작 전 질문할 것)

다음은 사용자 답변 없이는 진행 불가:

1. **Apple Developer Team ID**: `Project.swift`의 `DEVELOPMENT_TEAM`에 입력 필요. Personal Team이라면 빈 값으로 두고 사용자가 Xcode에서 수동 선택.
2. **Bundle ID 확정**: 기본값 `com.provika.app` 사용해도 되는지.
3. **License**: MIT / Apache 2.0 / Proprietary 중 선택.
4. **App Icon**: 임시 플레이스홀더로 진행할지, 사용자가 별도 제공할지.

---

## 12. 참고 자료

- [Tuist 공식 문서](https://docs.tuist.dev)
- [TuistStrings (ResourceSynthesizers)](https://docs.tuist.dev/en/guides/develop/projects/synthesized-files)
- [AVFoundation Programming Guide](https://developer.apple.com/av-foundation/)
- [CryptoKit](https://developer.apple.com/documentation/cryptokit)
- [SwiftData](https://developer.apple.com/documentation/swiftdata)
- [Apple HIG — Camera](https://developer.apple.com/design/human-interface-guidelines/camera)

---

**작업 시작 전 §11의 4가지 질문을 사용자에게 먼저 확인하세요.**
