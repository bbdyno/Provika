# Provika

[English](README.md) · **한국어** · [简体中文](README.zh-Hans.md) · [繁體中文](README.zh-Hant.md) · [日本語](README.ja.md)

**촬영하고, 패키지로 만들고, 검증합니다.**

Provika는 촬영 시점·장소·원본 무결성이 중요한 사진과 영상을 기록하는 iOS 앱입니다. 내보낼 수 있는 증거 패키지를 만들고 네트워크 없이 오프라인에서 무결성을 검증할 수 있습니다.

Provika는 교통 신고 전용 앱이 아닙니다. 사건 현장 기록, 시설 점검, 배송 및 자산 상태, 현장 작업처럼 나중에 검토할 수 있는 촬영 기록이 필요한 여러 상황에 사용할 수 있습니다.

> Provika는 파일의 무결성을 확인하기 위한 기술 정보를 제공합니다. 법적 감정을 대신하거나 법적 증거 능력을 판단하지 않으며, 특정 기관의 접수를 보장하지 않습니다. 촬영·내보내기·공유 시 지역 법령과 개인정보를 준수해야 합니다.

## Provika가 하는 일

1. 사진이나 영상을 촬영하며 시각, 허용된 경우의 위치 정보, 기기 맥락을 함께 기록합니다.
2. 원본 미디어를 보존하고 정규화된 claim을 생성합니다.
3. SHA-256 다이제스트를 계산하고 ECDSA P-256 키로 패키지에 서명합니다.
4. 서명 envelope와 독립 검증에 필요한 정보를 패키지에 저장합니다.
5. 서명에 사용한 Keychain 항목에 의존하지 않고 패키지 무결성을 검증합니다.
6. 검증을 통과한 읽기용 사본을 안전한 ZIP과 다국어 PDF 보고서로 내보냅니다.

## 주요 기능

| 영역 | 기능 |
| --- | --- |
| 사진·영상 증거 | 버전이 명시된 evidence claim, 원본 미디어 보존, 결정적인 패키지 동결, 유효성 검사 |
| 무결성 | SHA-256 다이제스트, ECDSA P-256 서명, 공개키 자료 내보내기, 오프라인 검증 |
| 카메라 | 실시간 프리뷰, 포커스·노출, 플래시, 줌 제어, 0.5배 울트라와이드, 방향 대응 출력, 연속 녹화 |
| 선녹화 | 0 / 5 / 15 / 30초 선녹화 버퍼 |
| 화면 내 맥락 | 영상 프레임에 날짜, 시각, GPS, 앱·기기 정보를 선택적으로 렌더링 |
| 내보내기 | 검증된 ZIP과 5개 언어의 읽기용 PDF 보고서 |
| 갤러리 | 로컬 기록 탐색, 필터, 재생, 검증 상태 확인, 선택, 공유, 삭제 |
| 빠른 촬영 | 제어 센터·잠금 화면 진입점, App Intents, ExtensionKit 잠금화면 카메라 확장 |
| 데이터 안전 | 기존 녹화 마이그레이션, 원본 불변 정책, 안전한 파일명, 심볼릭 링크 거부, 원자적 staging |
| 지역 대응 | 중국 본토용 claim·UI 정책을 포함한 하나의 글로벌 오프라인 Evidence Core. 중국 전용 코어를 별도로 만들지 않음 |

## 증거 패키지

동결된 v2 패키지에는 원본 미디어와 기계가 읽을 수 있는 검증 기록이 포함됩니다.

```text
EvidencePackage/
  <원본 미디어>
  claim.json
  signature.json
  manifest.json       # 해당 흐름에서 생성된 경우
Photo Evidence Report.pdf
```

PDF는 사람이 읽기 위한 사본이며 서명된 원본 자체가 아닙니다. 검증은 원본 패키지 파일을 대상으로 수행해야 합니다.

## 지원 언어

앱 UI, 권한 설명, 증거 보고서 문자열, App Store 메타데이터는 다음 언어를 지원합니다.

- 한국어
- 영어
- 중국어 간체
- 중국어 번체
- 일본어

서명되는 Evidence Core는 언어에 종속되지 않습니다. 번역된 표시 문구가 서명된 원본 관측값을 대체하지 않습니다.

## 개인정보와 오프라인 경계

- 증거 미디어와 패키지 데이터는 사용자가 직접 내보내거나 공유하기 전까지 기기에 보관됩니다.
- 촬영, 해시, 서명, 패키지 동결, 검증, ZIP 내보내기는 서비스 연결 없이 완료되도록 설계되었습니다.
- 위치 정보는 시스템 권한이 허용된 경우에만 기록하며, 기기의 원본 좌표와 표시용 변환 좌표를 구분합니다.
- Firebase 초기화는 로컬 `GoogleService-Info.plist`가 있을 때만 수행됩니다. 배포 전 실제 Release 구성과 개인정보 매니페스트를 확인해야 합니다.
- 잠금화면 카메라 확장은 Apple의 제한된 ExtensionKit 환경과 임시 세션 컨테이너 안에서 동작합니다.

## 기술 구성

| 항목 | 값 |
| --- | --- |
| 언어 | Swift 5.9+ |
| 최소 OS | iOS 18.0 |
| UI | SwiftUI + UIKit 브리지 |
| 카메라·미디어 | AVFoundation, Core Image |
| 저장 | SwiftData, FileManager |
| 위치 | CoreLocation |
| 무결성 | CryptoKit, Security 프레임워크, 가능한 경우 Secure Enclave |
| 빠른 촬영 | App Intents, WidgetKit, LockedCameraCapture, ExtensionKit |
| 프로젝트 생성 | Tuist 4.x |

## 저장소 구조

```text
Sources/
  App/                     앱 진입점과 내비게이션
  Core/
    Evidence/V2/           정규화 claim, 서명 payload, finalizer, verifier
    Export/                안전한 ZIP과 다국어 PDF 내보내기
    Localization/          언어 중립적인 확정 텍스트 정책
    LockedCapture/         잠금화면 촬영 가져오기와 handoff 정책
    Policy/                오프라인·지역 claim 경계
    Storage/               모델, 마이그레이션, 증거 데이터 안전
    Workflow/              촬영·녹화·내보내기 상태 머신
  Features/
    Camera/                사진·영상 촬영 파이프라인과 제어
    Gallery/               로컬 탐색과 상세 검증 UI
    Settings/              사용자 설정, 키, 후원 UI
  LockedCaptureExtension/  ExtensionKit 잠금화면 카메라 경험
  Widgets/                 빠른 촬영 컨트롤
Resources/                 에셋, 개인정보 매니페스트, 정책, 문자열 카탈로그
Tests/                     증거·워크플로·다국어·출시 테스트
Documentation/             설계 경계와 특성화 문서
```

## 빌드와 테스트

### 요구 사항

- iOS 18 SDK 이상을 포함한 Xcode
- Tuist 4.x

### 프로젝트 생성

```bash
tuist install
tuist generate --no-open
```

### 빌드

```bash
xcodebuild \
  -workspace Provika.xcworkspace \
  -scheme Provika \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

### 테스트

```bash
xcodebuild \
  -workspace Provika.xcworkspace \
  -scheme Provika \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

필요하면 시뮬레이터 이름을 로컬에 설치된 기기로 바꾸십시오. 하드웨어, 카메라 동작, Secure Enclave, 무선 상태, 잠금 기기 환경에 의존하는 주장은 실제 기기 증거가 필요합니다.

## 라이선스

Apache License 2.0. 자세한 내용은 [LICENSE](LICENSE)를 참조하십시오.
