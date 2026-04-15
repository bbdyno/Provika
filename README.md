# Provika

> 교통법규 위반 증거 영상 촬영 iOS 앱

Provika는 교통법규 위반 영상을 촬영하여 경찰·국민신문고 공익신고에 사용할 때 **증거자료로 인정받을 수 있는 신뢰성**을 갖춘 iOS 앱입니다.

## 주요 기능

- **타임스탬프·GPS 좌표 burn-in**: 프레임에 직접 합성되어 사후 편집 불가
- **SHA-256 해시 + Secure Enclave 디지털 서명**: 영상 무결성 보장
- **메타데이터 이중 기록**: 비디오 트랙 + 사이드카 JSON
- **녹화 연속성 보장**: 중간 일시정지 없이 연속 녹화
- **선녹화 버퍼**: 직전 5~30초 자동 보관, 위반 순간 놓침 방지

## 기술 스택

| 항목 | 기술 |
|---|---|
| 언어 | Swift 5.9+ |
| 최소 OS | iOS 17.0 |
| UI | SwiftUI + UIViewRepresentable (카메라 프리뷰) |
| 영상 캡처 | AVFoundation (AVCaptureSession + AVAssetWriter) |
| 오버레이 | Core Image |
| 위치 | CoreLocation |
| 저장 | SwiftData + FileManager |
| 보안 | CryptoKit (SHA-256), Security (Secure Enclave) |
| 빌드 | Tuist 4.x |

## 프로젝트 구조

```
Sources/
  App/          - 앱 진입점, 탭 네비게이션
  Features/
    Camera/     - 카메라 프리뷰, 녹화, 오버레이 burn-in
    Gallery/    - 날짜별 갤러리, 영상 재생, 메타데이터 표시
    Settings/   - 녹화 설정, 보안 키 관리
  Core/
    Location/   - 위치 서비스
    Storage/    - 파일 저장, SwiftData 모델, 사이드카 JSON
    Security/   - SHA-256 해시, Secure Enclave 서명
    DI/         - 의존성 주입
    Extensions/ - 유틸리티 확장
Resources/      - 다국어 문자열, Assets
Tests/          - 단위 테스트
```

## 빌드 방법

```bash
# Tuist 설치 (미설치 시)
curl -Ls https://install.tuist.io | bash

# 프로젝트 생성
tuist generate

# 빌드
xcodebuild \
  -workspace Provika.xcworkspace \
  -scheme Provika \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build

# 테스트
xcodebuild \
  -workspace Provika.xcworkspace \
  -scheme Provika \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

## 보안 설계

### 무결성 체인
1. 녹화 종료 → 영상 파일 SHA-256 해시 계산
2. 해시값을 Secure Enclave ECDSA P-256 키로 서명
3. 해시·서명·공개키를 사이드카 JSON에 기록
4. 검증 시: 파일 해시 재계산 → 공개키로 서명 검증

### 데이터 처리
- 모든 데이터는 기기 내 로컬 저장
- 서버 업로드 없음
- 사용자가 명시적으로 공유할 때만 외부 전송

## 라이선스

Apache License 2.0 - [LICENSE](LICENSE) 참조
