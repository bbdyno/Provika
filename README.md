# Provika

Provika is an iOS evidence-capture app for recording traffic-violation videos with burned-in timestamp and GPS data, local integrity metadata, and a reviewable gallery workflow.

> 한국어: Provika는 타임스탬프와 GPS를 영상 프레임에 직접 기록하고, 무결성 메타데이터와 갤러리 검토 흐름까지 포함한 교통법규 위반 증거 촬영용 iOS 앱입니다.

## Current Status

This repository is a working prototype with an end-to-end local workflow:

- record video from a live camera preview
- burn timestamp, GPS, and device/app footer directly into frames
- save a `.mov` file plus a sidecar JSON metadata file
- calculate a SHA-256 hash and attach an ECDSA signature
- browse, verify, share, and delete recordings in-app

The app UI stays portrait-first, but the capture pipeline now detects device orientation during recording and adapts recorded video dimensions and overlay layout for portrait vs. landscape footage.

> 한국어: 현재 저장소는 촬영, 오버레이 합성, 로컬 저장, 해시/서명, 갤러리 검토까지 한 사이클이 동작하는 프로토타입입니다. 앱 UI는 세로 기준이지만, 실제 녹화 파이프라인은 기기 방향을 감지해 세로/가로 영상과 오버레이 레이아웃을 자동으로 맞춥니다.

## Implemented Features

| Area | What is implemented |
| --- | --- |
| Camera | Live preview, tap-to-focus/expose, pinch zoom, flash toggle, recording timer, and a full-width semicircular zoom dial with centered zoom readout |
| Zoom UX | Drag-driven zoom control modeled after the iPhone camera style, with moving tick marks, sticky snap points, and haptic feedback around preferred zoom levels |
| Pre-record buffer | 0s / 5s / 15s / 30s buffer support, with the selected duration applied to the capture pipeline |
| Overlay burn-in | Timestamp, GPS coordinates, and app/device footer are composited into frames with Core Image |
| Orientation-aware output | Preview rotation, recorded dimensions, and overlay typography/layout adapt automatically to portrait and landscape capture |
| Integrity metadata | SHA-256 file hash, ECDSA P-256 signature, public key export, and sidecar JSON metadata |
| Gallery | Date-based filtering, thumbnail grid, actual video duration display, multi-select, drag-select, playback, share, mark-as-reported, and delete |
| Settings | Public key viewing and signing-key regeneration are functional; recording/overlay/storage preferences are persisted in `UserDefaults` |

> 한국어:
> 카메라 탭에는 실시간 프리뷰, 포커스, 플래시, 아이폰 스타일 반원 줌 다이얼, 선녹화 버퍼가 들어가 있습니다.
> 녹화 결과물에는 타임스탬프·GPS·기기 정보가 burn-in 되고, SHA-256 해시와 전자서명, sidecar JSON이 함께 저장됩니다.
> 갤러리에서는 날짜별 필터링, 재생, 공유, 신고 완료 표시, 다중 선택 삭제가 가능합니다.

## Integrity Model

1. Record a video and write a local `.mov` file.
2. Generate a SHA-256 hash for the recorded file.
3. Sign the hash payload with an ECDSA P-256 key.
4. Export the public key and store integrity data in the sidecar JSON.
5. Re-verify the stored signature from the detail screen when needed.

On real devices, the signing key is created in Secure Enclave when available. On the simulator, the app falls back to a regular Keychain-backed key so development and tests can still run.

> 한국어: 녹화가 끝나면 파일 해시를 계산하고, ECDSA P-256 키로 서명한 뒤 공개키와 함께 sidecar JSON에 저장합니다. 실기기에서는 가능하면 Secure Enclave를 사용하고, 시뮬레이터에서는 일반 Keychain 키로 대체합니다.

## Architecture

| Item | Value |
| --- | --- |
| Language | Swift 5.9+ |
| Minimum OS | iOS 17.0 |
| UI | SwiftUI + `UIViewRepresentable` |
| Camera / Media | AVFoundation (`AVCaptureSession`, `AVAssetWriter`) |
| Overlay rendering | Core Image + UIKit text rendering |
| Persistence | SwiftData + FileManager |
| Location | CoreLocation |
| Security | CryptoKit + Security framework |
| Project generation | Tuist 4.x |

> 한국어: SwiftUI를 중심으로 작성됐고, 카메라/녹화는 AVFoundation, 오버레이 합성은 Core Image, 저장은 SwiftData와 파일 시스템, 보안은 CryptoKit과 Security 프레임워크를 사용합니다.

## Repository Layout

```text
Sources/
  App/                    App entry point and tab navigation
  Core/
    DI/                   Shared app environment
    Extensions/           Formatting and utility extensions
    Location/             CoreLocation wrapper
    Security/             Hashing and signing services
    Storage/              File paths, metadata schema, SwiftData model
  Features/
    Camera/
      Services/           Capture pipeline, pre-record buffer, overlay renderer, writer
      ViewModels/         Camera state and save flow
      Views/              Preview, recording UI, zoom dial
    Gallery/
      ViewModels/         Gallery filtering and file deletion
      Views/              Grid, thumbnails, detail/player
    Settings/
      ViewModels/         Persisted preferences and key actions
      Views/              Recording, overlay, storage, security settings
Resources/                Strings and assets
Tests/                    Unit tests for hashing, storage, and app basics
```

> 한국어: 구조는 `App`, `Core`, `Features`로 나뉘고, 카메라/갤러리/설정 기능이 각각 분리되어 있습니다.

## Build and Test

### Prerequisites

- Xcode with the iOS 17 SDK or newer
- Tuist 4.x

### Generate the project

```bash
tuist generate
```

### Build

```bash
xcodebuild \
  -project Provika.xcodeproj \
  -scheme Provika \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

### Test

```bash
xcodebuild \
  -project Provika.xcodeproj \
  -scheme Provika \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

If the named simulator is not available on your machine, replace `iPhone 17 Pro` with any installed iPhone simulator.

> 한국어: `tuist generate`로 프로젝트를 만든 뒤 `xcodebuild`로 빌드/테스트하면 됩니다. 테스트용 시뮬레이터 이름은 로컬 환경에 맞게 바꾸면 됩니다.

## Known Gaps

- The app interface is portrait-only even though captured output adapts to device orientation.
- The pre-record duration setting is active, but the quality/codec selectors are not yet wired into the recording pipeline.
- Overlay visibility toggles and auto-delete policy are persisted in settings, but enforcement is not yet connected to capture/storage behavior.

> 한국어: 현재는 세로 UI 고정이고, 설정 화면의 일부 옵션은 값 저장까지는 되지만 실제 캡처 파이프라인과 완전히 연결되지는 않았습니다. 선녹화 시간 설정은 실제로 적용됩니다.

## Privacy

- All recordings and metadata are stored locally on the device.
- There is no backend upload flow in the current implementation.
- Data leaves the device only when the user explicitly shares a recording.

> 한국어: 현재 구현에는 서버 업로드가 없고, 모든 데이터는 기기 로컬에 저장됩니다. 외부 전송은 사용자가 직접 공유할 때만 일어납니다.

## License

Apache License 2.0. See [LICENSE](LICENSE).

> 한국어: 라이선스는 Apache License 2.0입니다.
