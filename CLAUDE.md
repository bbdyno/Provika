# Provika iOS — 작업 지침

이 문서는 이 저장소에서 작업할 때의 지침서입니다. 작업 시작 전에 먼저 읽으십시오.

> 이 문서는 2026-08-29 에 실제 저장소 상태(2.0)에 맞춰 다시 썼습니다. 이전 판은 v1.0 계획서로,
> 교통 위반 영상 전용 앱을 전제하고 있어 현재 코드와 어긋나 있었습니다.

---

## 0. 이 저장소가 지키려는 것

Provika는 카메라 앱이 아니라 **서명된 증거 포맷을 정의하는 앱**입니다. UI 가 어떻게 생겼는지보다, 만들어진 패키지가 나중에 독립적으로 검증되는지가 중요합니다.

따라서 다음 세 가지는 다른 어떤 편의보다 우선합니다.

1. **Android 판과의 교차 검증이 깨지지 않을 것.** 증거 포맷을 건드렸다면 Android 저장소의 `tools/verify-with-ios.sh` 를 반드시 돌립니다.
2. **관측값을 지어내지 않을 것.** 위치를 못 받았으면 좌표를 비워 두고, 플랫폼이 다르면 다른 값을 정직하게 적고 계약을 넓힙니다.
3. **부분 패키지를 노출하지 않을 것.** 모든 아티팩트를 스테이징에 만든 뒤 단 한 번의 이동으로 공개합니다. 이미 있는 목적지는 절대 덮어쓰지 않습니다.

## 1. 작업 원칙

1. **빌드·테스트 검증**: 변경 후 `tuist generate --no-open` 과 아래 테스트 명령을 통과시킵니다.
2. **추측 금지**: 명세가 모호하면 코드를 쓰기 전에 사용자에게 질문합니다.
3. **Apple 프레임워크 위주**: 빌드 도구로 Tuist 를 쓰고, 조건부 Firebase 외에는 외부 의존성을 늘리지 않습니다.
4. **언어 정책**
   - 코드 식별자(변수·함수·타입·파일명): **영문**
   - 주석·커밋 메시지·문서: **한글**
   - 사용자 노출 문자열: **반드시 문자열 카탈로그** (하드코딩 금지)
5. **문자열 카탈로그 정책**: 카탈로그 테스트가 다음을 강제합니다.
   - 모든 키가 5개 로케일(en, ko, zh-Hans, zh-Hant, ja)을 갖출 것
   - 모든 항목의 주석이 잠정 번역 고지일 것
   - `InfoPlist.xcstrings` 는 권한 설명 4개만 있을 것
   Xcode 가 자동 추출한 항목(예: `Text(" ")` 의 공백)이 들어오면 테스트가 깨집니다. 카탈로그에서 지우고 소스를 `Text(verbatim:)` 로 고치십시오.
6. **커밋 단위**: 기능 단위로 의미 있는 한글 커밋 메시지.

## 2. 기술 스택

| 항목 | 값 |
| --- | --- |
| 언어 | Swift 5.9+ |
| 최소 OS | iOS 18.0 |
| UI | SwiftUI + UIKit 브리지 |
| 카메라·미디어 | AVFoundation, Core Image |
| 저장 | SwiftData, FileManager |
| 위치 | CoreLocation |
| 무결성 | CryptoKit, Security, 가능한 경우 Secure Enclave |
| 빠른 촬영 | App Intents, WidgetKit, LockedCameraCapture, ExtensionKit |
| 결제 | StoreKit 2 (소모성 후원 3종) |
| 빌드 | Tuist 4.x |

## 3. 타깃 구성

| 타깃 | 번들 ID | 역할 |
| --- | --- | --- |
| Provika | `com.bbdyno.app.provika` | 앱 |
| ProvikaWidgets | `…provika.widgets` | Control Widget |
| ProvikaLockedCapture | `…provika.locked-capture` | 잠금 상태 카메라(ExtensionKit) |
| ProvikaTests | `…provika.tests` | 단위 테스트 |

`Project.swift` 가 단일 진실 원본입니다. `GoogleService-Info.plist` 는 저장소에 포함하지 않으며, 파일이 있는 환경에서만 리소스로 추가됩니다.

## 4. 증거 포맷을 건드릴 때

증거 포맷은 iOS 와 Android 두 저장소가 공유하는 계약입니다. 한쪽만 고치면 깨집니다.

### 검증기의 성질 두 가지

- **사진 검증기**는 `claim.json` 을 **디스크 바이트 그대로** 해시합니다. 재직렬화하지 않으므로 인코더 차이의 영향을 받지 않습니다.
- **영상 검증기**는 여기에 더해 `claim.canonicalData() == claimData` 로 **정규형 바이트 일치**까지 확인합니다. 그래서 다음이 따라옵니다.
  - 다른 플랫폼이 기록한 필드를 이 저장소의 모델도 알고 있어야 합니다. 모르는 필드가 있으면 재직렬화 결과가 달라져 **유효한 패키지가 거부됩니다.**
  - `location` 과 `attestation` 을 영상 클레임에 둔 이유가 이것입니다. iOS 파이프라인은 채우지 않지만 값을 잃지 않기 위해 스키마에 있습니다.

### 플랫폼 간 계약

| 계약 | iOS | Android | 이유 |
| --- | --- | --- | --- |
| 영상 컨테이너 | `original.mov` / `video/quicktime` | `original.mp4` / `video/mp4` | Android `MediaMuxer` 가 QuickTime 을 출력하지 못함 |
| 위치 출처 | `core-location-device` | `fused-location-device` | Android 좌표는 Fused Location Provider 에서 옴 |

`VideoEvidenceMediaContract` 와 `EvidenceLocationSourceContract` 가 양쪽 값을 모두 인정합니다. 이 플랫폼은 계속 자기 네이티브 값을 기록합니다.

### 사진 패키지는 파일 3개 고정

검증기가 `Set(names) == {claim.json, signature.json, 미디어}` 를 요구합니다. 추가 정보는 파일이 아니라 **클레임 안의 선택 필드**로 넣으십시오. 썸네일 같은 파생물은 패키지 바깥에 둡니다.

### 검증 순서

```bash
xcodebuild -workspace Provika.xcworkspace -scheme Provika \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO test

# 최종 판정: Android 저장소에서
~/Repository/Provika-Android/tools/verify-with-ios.sh "$PWD"
```

## 5. 빌드 명령

```bash
tuist install
tuist generate --no-open

xcodebuild -workspace Provika.xcworkspace -scheme Provika \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

시뮬레이터 이름은 설치된 것으로 바꿔 쓰십시오. 하드웨어·Secure Enclave·잠금 상태 환경에 의존하는 주장은 실기기 검증이 필요합니다.

## 6. 릴리스

`Release/AppStoreConnect/2.0/` 에 5개 언어 등록정보가 있습니다. 과장 표현 금지 정책(`ChinaClaimsPolicy`)이 스토어 문구에도 적용됩니다. "법적 효력 보장", "위변조 불가", "공식 인증" 같은 표현은 쓰지 않습니다.

## 7. 사이트와 정책 문서

- `docs/` — Firebase Hosting(프로젝트 `provika-ios`). `firebase deploy` 로 배포합니다.
  공개 주소는 **`https://provika-ios.web.app`** 입니다.
- **`provika.app` 은 우리 도메인이 아닙니다.** 2026-08-31 확인 결과 "Provika Reviews"라는
  스페인어권 구글 리뷰 서비스가 쓰고 있고 `/privacy`, `/support` 는 404 입니다.
  등록정보에 그 주소를 넣으면 사용자가 남의 회사 사이트로 갑니다. 자체 도메인을 잡기 전까지
  스토어 주소는 `provika-ios.web.app` 을 씁니다.
- **App Store Connect 의 라이브 등록정보에도 같은 주소가 들어가 있을 수 있습니다.**
  저장소 파일만 고쳐서는 이미 게시된 링크가 바뀌지 않습니다. Connect 에서 직접 확인하십시오.
- `docs/terms.html`, `docs/privacy.html` — **iOS 와 Android 공통 문서**입니다. 한쪽 플랫폼만 고치지 마십시오. 스토어에 따라 달라지는 결제·환불만 조항 안에서 나눠 두었습니다.
- 문구는 `docs/app.js` 의 `translations` 에 ko/en 두 벌로 들어 있습니다. HTML 의 `data-i18n` 키와 사전이 어긋나면 번역이 빠집니다.
- 로컬 미리보기: `.claude/launch.json` 의 `docs` 설정으로 정적 서버를 띄울 수 있습니다.

스토어 배지는 현재 자리표시자입니다. 출시 전에 Apple 과 Google 이 제공하는 **공식 배지 이미지**로 교체해야 합니다. 양사 브랜드 지침이 배지 아트워크의 자체 제작을 금지합니다.

## 8. 관련 저장소

- Android 판: [bbdyno/Provika-Android](https://github.com/bbdyno/Provika-Android)
- 두 저장소는 같은 증거 포맷을 쓰고 서로의 패키지를 검증합니다. Android 저장소의 `CLAUDE.md` 에 그쪽 관점의 같은 계약이 정리돼 있습니다.
