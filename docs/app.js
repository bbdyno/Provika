const metaByPage = {
  home: {
    ko: {
      title: "Provika",
      description:
        "Provika는 사진과 영상에 시각·위치를 새기고, 해시와 전자서명을 담은 증거 패키지를 만드는 iPhone·Android 앱입니다. 검증은 네트워크 없이 기기 안에서 끝납니다."
    },
    en: {
      title: "Provika",
      description:
        "Provika is an evidence capture app for iPhone and Android that burns time and location into photos and videos and builds signed, offline-verifiable evidence packages."
    }
  },
  privacy: {
    ko: {
      title: "Provika 개인정보 처리방침",
      description: "Provika 개인정보 처리방침"
    },
    en: {
      title: "Provika Privacy Policy",
      description: "Provika Privacy Policy"
    }
  },
  terms: {
    ko: {
      title: "Provika 이용 약관",
      description: "Provika 이용 약관"
    },
    en: {
      title: "Provika Terms of Use",
      description: "Provika Terms of Use"
    }
  },
  "404": {
    ko: {
      title: "Provika",
      description: "Provika service page"
    },
    en: {
      title: "Provika",
      description: "Provika service page"
    }
  }
};

const translations = {
  "ko": {
    "nav.workflow": "증거 흐름",
    "nav.surfaces": "핵심 화면",
    "nav.trust": "보관과 신뢰",
    "nav.support": "지원",
    "nav.privacy": "개인정보 처리방침",
    "nav.terms": "이용 약관",
    "hero.eyebrow": "ON-DEVICE EVIDENCE CAPTURE FOR IPHONE AND ANDROID",
    "hero.title": "촬영한 순간을 그대로 남기고, 나중에 직접 검증할 수 있게",
    "hero.body": "Provika는 사진과 영상을 촬영하면서 시각·위치·기기 정보를 프레임에 새기고, 원본에 대한 해시와 전자서명을 담은 증거 패키지를 만듭니다. 검증은 네트워크 없이 기기 안에서 끝납니다.",
    "hero.primary": "증거 흐름 보기",
    "hero.secondary": "개인정보 처리방침",
    "hero.stat1.label": "기록 방식",
    "hero.stat1.value": "프레임 내 시간·위치 각인",
    "hero.stat2.label": "무결성",
    "hero.stat2.value": "SHA-256 + ECDSA P-256",
    "hero.stat3.label": "검증",
    "hero.stat3.value": "네트워크 없이 오프라인",
    "hero.visual.state": "RECORD READY",
    "hero.visual.badge": "Evidence Burn-In",
    "hero.card1.kicker": "EVIDENCE PACKAGE",
    "hero.card1.title": "원본과 검증 자료를 한 묶음으로 보관",
    "hero.card1.body": "원본 미디어, 정규화된 클레임, 서명 봉투를 한 패키지에 담아 내보냅니다. 읽기용 PDF 보고서는 5개 언어로 함께 나갑니다.",
    "hero.card2.kicker": "INTEGRITY STATUS",
    "hero.card2.item1": "원본 미디어 해시 생성",
    "hero.card2.item2": "보안 하드웨어 키로 서명",
    "hero.card2.item3": "갤러리에서 다시 검증",
    "hero.card2.status": "READY",
    "workflow.eyebrow": "EVIDENCE WORKFLOW",
    "workflow.title": "촬영, 각인, 서명, 검증까지 이어지는 증거 흐름",
    "workflow.body": "Provika는 단순 카메라가 아니라 촬영 순간의 시간과 위치를 프레임에 새기고, 원본과 검증 자료를 한 묶음으로 보존하는 도구입니다.",
    "workflow.step1.title": "즉시 촬영",
    "workflow.step1.body": "실시간 미리보기와 선녹화 버퍼, 포커스·줌·플래시 제어로 현장 기록을 바로 시작합니다.",
    "workflow.step2.title": "프레임 각인",
    "workflow.step2.body": "시각, GPS 좌표, 앱·기기 정보가 촬영 프레임에 직접 합성되어 별도 도구 없이도 확인할 수 있습니다.",
    "workflow.step3.title": "해시와 서명",
    "workflow.step3.body": "촬영이 끝나면 원본 해시를 계산하고, 보안 하드웨어에 보관된 키로 서명해 패키지를 원자적으로 발행합니다.",
    "workflow.step4.title": "검증과 내보내기",
    "workflow.step4.body": "갤러리에서 저장된 패키지를 다시 검증하고, 검증을 통과한 것만 읽기용 보고서와 함께 내보냅니다.",
    "surfaces.eyebrow": "KEY SURFACES",
    "surfaces.title": "현장에서 필요한 화면만 남긴 구성",
    "surfaces.card1.kicker": "Capture",
    "surfaces.card1.title": "한 손으로 다루는 카메라",
    "surfaces.card1.body": "큰 촬영 버튼과 줌 슬라이더만 남겼습니다. 짧게 누르면 녹화, 길게 누르면 사진입니다.",
    "surfaces.card2.kicker": "Quick Capture",
    "surfaces.card2.title": "앱을 열지 않고 바로 촬영",
    "surfaces.card2.body": "iPhone은 제어 센터와 액션 버튼, Android는 빠른 설정 타일·위젯·볼륨 키로 곧바로 촬영을 시작합니다.",
    "surfaces.card3.kicker": "Review",
    "surfaces.card3.title": "갤러리와 검증 상태",
    "surfaces.card3.body": "저장된 패키지를 날짜별로 정리하고, 파일을 다시 읽어 검증한 결과를 함께 보여 줍니다.",
    "surfaces.card4.kicker": "Settings",
    "surfaces.card4.title": "기록 정책과 서명 키 관리",
    "surfaces.card4.body": "선녹화 길이, 각인 항목, 보관 정책, 공개키 확인과 서명 키 재생성을 설정에서 다룹니다.",
    "trust.eyebrow": "LOCAL-FIRST TRUST MODEL",
    "trust.title": "기기 안에 남고, 사용자가 내보낼 때만 밖으로 나갑니다",
    "trust.card1.kicker": "ON DEVICE",
    "trust.card1.title": "서버로 보내는 흐름이 없습니다",
    "trust.card1.body": "미디어, 클레임, 해시, 서명은 기기의 앱 전용 저장소에 남습니다. 자동 클라우드 백업과 기기 간 전송에서도 앱 데이터를 제외했습니다.",
    "trust.card1.item1": "원본과 검증 자료를 기기 안에 보관",
    "trust.card1.item2": "서명 키는 Secure Enclave 또는 Android Keystore 안에서 생성",
    "trust.card1.item3": "갤러리에서 파일을 다시 읽어 검증",
    "trust.card2.kicker": "WHEN DATA LEAVES",
    "trust.card2.title": "사용자가 내보낼 때만 전송",
    "trust.card2.body": "내보내기와 공유는 사용자가 직접 실행할 때만 일어나고, 검증을 통과한 패키지만 나갑니다.",
    "trust.card3.kicker": "WHAT IT DOES NOT CLAIM",
    "trust.card3.title": "기술적 무결성 정보이지 법적 판단이 아닙니다",
    "trust.card3.body": "해시는 패키지 생성 이후의 변경을 확인하는 데 쓰이고, 시각과 위치는 기기가 보고한 관측값입니다. 증거 채택 여부를 보증하지 않습니다.",
    "support.eyebrow": "SUPPORT & LEGAL",
    "support.title": "프로젝트 정보와 정책 문서",
    "support.body": "연락은 이메일과 GitHub 프로필을 통해 받습니다. 정책 문서는 iPhone과 Android에 함께 적용되며 한국어와 영어로 제공합니다.",
    "support.card1.label": "이메일 문의",
    "support.card1.meta": "직접 문의를 보낼 수 있는 기본 연락 채널입니다.",
    "support.card2.label": "GitHub 프로필",
    "support.card2.meta": "프로젝트 업데이트와 공개 저장소를 확인할 수 있는 연락 프로필입니다.",
    "support.card3.label": "정책 문서",
    "support.card3.title": "개인정보 처리방침과 이용 약관",
    "support.card3.meta": "카메라·마이크·위치 권한, 기기 내 보관, 스토어별 결제와 환불 기준을 문서로 제공합니다.",
    "footer.privacy": "개인정보 처리방침",
    "footer.terms": "이용 약관",
    "legal.nav.home": "홈",
    "legal.footer.home": "홈으로",
    "404.eyebrow": "NOT FOUND",
    "404.title": "요청한 페이지를 찾을 수 없습니다",
    "404.body": "주소를 다시 확인하거나 Provika 서비스 홈으로 이동해 주세요.",
    "404.cta": "홈으로 이동",
    "terms.eyebrow": "TERMS OF USE",
    "terms.title": "이용 약관",
    "terms.updated": "최종 업데이트: 2026년 8월 29일",
    "terms.intro": "본 약관은 iOS 판과 Android 판 Provika에 함께 적용됩니다. 결제·환불처럼 스토어에 따라 달라지는 사항은 해당 조항에서 따로 구분합니다.",
    "terms.section1.title": "1. 서비스 목적",
    "terms.section1.body": "Provika는 촬영 시각·위치·기기 정보를 함께 남기고, 원본 미디어에 대한 해시와 전자서명을 담은 증거 패키지를 만드는 촬영 도구입니다. 교통 위반 신고에만 쓰이는 앱은 아니며 사고 기록, 점검, 배송·현장 기록 등에도 사용할 수 있습니다. 법률 자문, 수사 대행, 공공기관 제출 결과를 보장하는 서비스가 아닙니다.",
    "terms.section2.title": "2. 무엇을 보장하고 무엇을 보장하지 않는가",
    "terms.section2.body": "Provika는 기술적 무결성 정보를 제공합니다. 해시는 패키지 생성 이후 미디어가 바뀌었는지 확인하는 데 쓰이고, 서명은 키와 정규화된 클레임의 결합을 검증합니다. 기록된 시각과 위치는 기기가 보고한 관측값이며 그 자체로 진실을 증명하지 않습니다. 특정 기관이나 절차에서 이 자료가 증거로 채택될 것이라고 보증하지 않으며, 포렌식 분석을 대체하지도 않습니다.",
    "terms.section3.title": "3. 사용자 책임",
    "terms.section3.body": "촬영·보관·공유·신고의 적법성 판단은 사용자에게 있습니다. 현지 법규와 타인의 프라이버시를 존중해야 하며, 운전 중이거나 위험한 상황에서 기기를 조작해서는 안 됩니다. 빠른 실행 기능(잠금화면 바로가기, 빠른 설정 타일, 볼륨 키, 위젯)은 조작 부담을 줄이기 위한 것이지 주행 중 조작을 권장하는 것이 아닙니다.",
    "terms.section4.title": "4. 지원 플랫폼과 기능 차이",
    "terms.section4.body": "iOS 판과 Android 판은 같은 증거 포맷을 쓰며 서로가 만든 패키지를 검증할 수 있습니다. 다만 플랫폼과 기기에 따라 제공되는 기능이 다릅니다. iOS 는 QuickTime 컨테이너와 Secure Enclave 를, Android 는 MP4 컨테이너와 Android Keystore(StrongBox 또는 TEE)를 사용합니다. 하드웨어 키 증명, 초광각, 잠금화면 진입점, 오버레이가 사진에 적용되는지 여부는 기기에 따라 달라질 수 있습니다.",
    "terms.section5.title": "5. 결제와 환불",
    "terms.section5.body": "앱 안의 후원 상품은 각 스토어의 결제 수단으로만 구매할 수 있습니다. App Store 에서 구매한 경우 Apple 의 환불 절차를, Google Play 에서 구매한 경우 Google Play 의 환불 정책을 따릅니다. 후원은 개발을 지원하기 위한 것이며 별도 기능을 해제하지 않습니다. 환불 요청은 구매한 스토어를 통해 접수해 주십시오.",
    "terms.section6.title": "6. 기능 변경",
    "terms.section6.body": "기능은 사전 공지 없이 변경, 개선, 제한 또는 중단될 수 있습니다. 다만 이미 생성된 증거 패키지를 나중에 읽지 못하게 만드는 변경은 하지 않으며, 증거 포맷을 바꿀 때는 기존 패키지가 계속 검증되도록 유지합니다.",
    "terms.section7.title": "7. 지식재산권",
    "terms.section7.body": "앱, 브랜드, 디자인, 문구 및 서비스 구성 요소에 대한 권리는 별도 명시가 없는 한 Provika 운영자 또는 해당 권리자에게 귀속됩니다. 사용자가 촬영한 미디어와 그 증거 패키지에 대한 권리는 사용자에게 있습니다.",
    "terms.section8.title": "8. 보증 제한과 책임 한도",
    "terms.section8.body": "서비스는 현 상태 그대로 제공되며, 모든 환경에서 무중단 동작, 오류 없음, 법적 적합성 또는 특정 목적 적합성을 보증하지 않습니다. 법이 허용하는 범위에서 운영자는 서비스 사용으로 인한 간접적·부수적 손해에 대해 책임을 지지 않습니다. 소비자 보호 법령이 부여하는 권리는 본 조항으로 제한되지 않습니다.",
    "terms.section9.title": "9. 문의 및 고지",
    "terms.section9.body": "본 약관의 중요한 변경 사항은 이 페이지에 반영됩니다. 문의는 이메일 또는 GitHub 프로필을 통해 받습니다.",
    "privacy.eyebrow": "PRIVACY POLICY",
    "privacy.title": "개인정보 처리방침",
    "privacy.updated": "최종 업데이트: 2026년 8월 29일",
    "privacy.intro": "본 방침은 iOS 판과 Android 판 Provika에 함께 적용됩니다. 한 줄로 요약하면, Provika는 사용자의 데이터를 수집하지 않으며 서버로 보내지 않습니다.",
    "privacy.section1.title": "1. 수집하지 않는 것",
    "privacy.section1.body": "Provika는 계정을 만들지 않고, 사용자를 식별하지 않으며, 촬영한 미디어나 위치를 운영자의 서버로 보내지 않습니다. 운영자는 사용자가 무엇을 촬영했는지 알 수 없습니다. 앱에는 백엔드 업로드 기능 자체가 없습니다.",
    "privacy.section2.title": "2. 기기 안에 저장되는 것",
    "privacy.section2.body": "촬영한 원본 미디어, 촬영 시각·위치·기기 정보를 담은 클레임, 해시와 서명이 담긴 봉투, 갤러리 조회용 인덱스, 앱 설정이 기기의 앱 전용 저장소에 남습니다. 서명 키는 기기의 보안 하드웨어 안에서 만들어지고 앱 밖으로 나오지 않습니다.",
    "privacy.section3.title": "3. 권한을 쓰는 이유",
    "privacy.section3.body": "카메라는 촬영에, 마이크는 영상의 음성 기록에, 위치는 촬영 위치 기록에 사용합니다. Android 에서는 녹화 중 상시 알림을 위해 알림 권한을 함께 요청합니다. 어떤 권한도 광고나 분석 목적으로 쓰이지 않으며, 거부해도 해당 기능만 빠진 채로 앱을 쓸 수 있습니다. 위치 권한이 없으면 좌표를 지어내지 않고 기록에 남기지 않습니다.",
    "privacy.section4.title": "4. 데이터가 기기를 벗어나는 유일한 경우",
    "privacy.section4.body": "사용자가 직접 내보내기나 공유를 실행할 때만 데이터가 기기 밖으로 나갑니다. 그 이후 데이터가 어디로 가는지는 사용자가 고른 앱이나 서비스의 정책을 따릅니다. 자동 클라우드 백업과 기기 간 전송에서도 앱 데이터를 제외하도록 설정해 두었으므로, 기기를 바꿔도 증거가 자동으로 따라가지 않습니다.",
    "privacy.section5.title": "5. 제3자 제공과 분석 도구",
    "privacy.section5.body": "운영자는 사용자 정보나 촬영 데이터를 판매하지 않습니다. 출시 빌드에는 분석 SDK 를 포함하지 않으며, 앱은 광고를 제공하지 않습니다. 앞으로 분석 도구를 도입하게 되면 이 방침과 스토어의 데이터 안전 정보에 먼저 반영합니다.",
    "privacy.section6.title": "6. 보관과 삭제",
    "privacy.section6.body": "보관 기간은 사용자가 정합니다. 앱 안에서 개별 기록을 지울 수 있고, 미신고 기록을 30일 또는 90일 뒤 자동으로 지우도록 설정할 수도 있습니다. 앱을 삭제하면 앱 전용 저장소의 데이터도 함께 사라집니다. 운영자 측에는 지울 사본이 없습니다.",
    "privacy.section7.title": "7. 보안과 그 한계",
    "privacy.section7.body": "무결성 확인을 위해 SHA-256 해시와 ECDSA P-256 서명을 만듭니다. 서명 키는 iOS 에서는 Secure Enclave, Android 에서는 Android Keystore(가능한 기기에서는 StrongBox)에 보관됩니다. Android 에서는 키가 실제 보안 하드웨어에서 만들어졌음을 증명하는 인증서를 함께 담을 수 있으며, 이는 키에 대한 사실일 뿐 촬영 내용의 진위와는 무관합니다. 어떤 방식도 절대적인 보안을 보장하지는 않습니다.",
    "privacy.section8.title": "8. 아동",
    "privacy.section8.body": "Provika는 아동을 대상으로 하지 않으며, 아동으로부터 개인정보를 수집하지 않습니다.",
    "privacy.section9.title": "9. 문의",
    "privacy.section9.body": "본 방침에 대한 문의는 이메일 또는 GitHub 프로필을 통해 접수할 수 있습니다.",
    "nav.platforms": "iPhone · Android",
    "store.ios.kicker": "App Store에서 받기",
    "store.android.kicker": "Google Play 출시 예정",
    "platforms.eyebrow": "ONE FORMAT, TWO PLATFORMS",
    "platforms.title": "iPhone과 Android가 서로의 증거 패키지를 검증합니다",
    "platforms.body": "두 앱은 같은 증거 포맷을 씁니다. 한쪽에서 만든 패키지를 다른 쪽 검증기가 그대로 확인할 수 있습니다. 기기에 맞는 부분만 각 플랫폼의 방식을 따르고, 그 사실은 패키지 안에 그대로 기록됩니다.",
    "platforms.ios.title": "iOS 18 이상",
    "platforms.ios.item1": "QuickTime 컨테이너 · Secure Enclave 서명 키",
    "platforms.ios.item2": "제어 센터 · 잠금화면 · 액션 버튼 원터치 촬영",
    "platforms.ios.item3": "잠금 상태 카메라 익스텐션",
    "platforms.android.title": "Android 10 이상 · 갤럭시 최적화",
    "platforms.android.item1": "MP4 컨테이너 · Android Keystore(StrongBox) 서명 키",
    "platforms.android.item2": "빠른 설정 타일 · 홈 위젯 · 런처 숏컷 · 볼륨 키 촬영",
    "platforms.android.item3": "잠금화면 바로가기와 측면 버튼 두 번 누르기 안내",
    "platforms.android.item4": "하드웨어 키 증명서를 패키지에 함께 보관",
    "platforms.note": "하드웨어 키 증명은 서명 키가 실제 보안 하드웨어에서 만들어졌다는 사실만 말합니다. 촬영 내용의 진위나 법적 효력과는 무관합니다."
  },
  "en": {
    "nav.workflow": "Workflow",
    "nav.surfaces": "Surfaces",
    "nav.trust": "Trust",
    "nav.support": "Support",
    "nav.privacy": "Privacy Policy",
    "nav.terms": "Terms of Use",
    "hero.eyebrow": "ON-DEVICE EVIDENCE CAPTURE FOR IPHONE AND ANDROID",
    "hero.title": "Capture the moment as it was, and verify it yourself later",
    "hero.body": "Provika burns time, location, and device context into the frame as you shoot photo or video, then builds an evidence package carrying a hash of the original and a digital signature. Verification finishes on the device, with no network.",
    "hero.primary": "See the Workflow",
    "hero.secondary": "Privacy Policy",
    "hero.stat1.label": "How it records",
    "hero.stat1.value": "Time and place burned into the frame",
    "hero.stat2.label": "Integrity",
    "hero.stat2.value": "SHA-256 + ECDSA P-256",
    "hero.stat3.label": "Verification",
    "hero.stat3.value": "Offline, no service needed",
    "hero.visual.state": "RECORD READY",
    "hero.visual.badge": "Evidence Burn-In",
    "hero.card1.kicker": "EVIDENCE PACKAGE",
    "hero.card1.title": "The original and its verification material, kept together",
    "hero.card1.body": "An export carries the original media, a canonical claim, and the signature envelope in one package, alongside a readable PDF report in five languages.",
    "hero.card2.kicker": "INTEGRITY STATUS",
    "hero.card2.item1": "Hash of the original media",
    "hero.card2.item2": "Signed with a secure-hardware key",
    "hero.card2.item3": "Re-verified in the gallery",
    "hero.card2.status": "READY",
    "workflow.eyebrow": "EVIDENCE WORKFLOW",
    "workflow.title": "Capture, burn in, sign, verify",
    "workflow.body": "Provika is not just a camera. It burns the time and place of capture into the frame and keeps the original together with the material needed to check it.",
    "workflow.step1.title": "Capture immediately",
    "workflow.step1.body": "Live preview, a pre-record buffer, and focus, zoom, and flash controls so you can start recording on the spot.",
    "workflow.step2.title": "Burn into the frame",
    "workflow.step2.body": "Time, GPS coordinates, and app and device context are composited into the captured frame, readable without any special tool.",
    "workflow.step3.title": "Hash and sign",
    "workflow.step3.body": "When capture ends, the original is hashed and signed with a key held in secure hardware, and the package is published atomically.",
    "workflow.step4.title": "Verify and export",
    "workflow.step4.body": "The gallery re-verifies stored packages from their files, and only packages that pass are exported with a reading report.",
    "surfaces.eyebrow": "KEY SURFACES",
    "surfaces.title": "Only the screens a field capture actually needs",
    "surfaces.card1.kicker": "Capture",
    "surfaces.card1.title": "A camera you can work one-handed",
    "surfaces.card1.body": "A large capture button and a zoom slider, nothing more. Tap to record, hold for a photo.",
    "surfaces.card2.kicker": "Quick Capture",
    "surfaces.card2.title": "Start without opening the app",
    "surfaces.card2.body": "Control Center and the Action button on iPhone; quick settings tile, widget, and volume key on Android.",
    "surfaces.card3.kicker": "Review",
    "surfaces.card3.title": "Gallery and verification state",
    "surfaces.card3.body": "Packages are organized by date and shown with the result of re-reading and verifying their files.",
    "surfaces.card4.kicker": "Settings",
    "surfaces.card4.title": "Recording policy and key management",
    "surfaces.card4.body": "Pre-record length, overlay items, retention policy, public key inspection, and signing key regeneration.",
    "trust.eyebrow": "LOCAL-FIRST TRUST MODEL",
    "trust.title": "It stays on the device, and leaves only when you export it",
    "trust.card1.kicker": "ON DEVICE",
    "trust.card1.title": "There is no path that uploads to a server",
    "trust.card1.body": "Media, claims, hashes, and signatures live in the app's private storage. App data is excluded from automatic cloud backup and device-to-device transfer as well.",
    "trust.card1.item1": "Original and verification material kept on device",
    "trust.card1.item2": "Signing key created inside the Secure Enclave or Android Keystore",
    "trust.card1.item3": "Gallery re-reads the files to verify",
    "trust.card2.kicker": "WHEN DATA LEAVES",
    "trust.card2.title": "Sent only when you export",
    "trust.card2.body": "Export and share happen only when you choose them, and only packages that pass verification leave the device.",
    "trust.card3.kicker": "WHAT IT DOES NOT CLAIM",
    "trust.card3.title": "Technical integrity information, not a legal judgment",
    "trust.card3.body": "A hash detects change after the package was created; time and location are observations reported by the device. Acceptance as evidence is not guaranteed.",
    "support.eyebrow": "SUPPORT & LEGAL",
    "support.title": "Project information and policy pages",
    "support.body": "Reach us by email or through the GitHub profile. The policy documents apply to both iPhone and Android and are available in Korean and English.",
    "support.card1.label": "Email Contact",
    "support.card1.meta": "Primary direct contact channel for questions and support.",
    "support.card2.label": "GitHub Profile",
    "support.card2.meta": "Public profile for project updates and repository access.",
    "support.card3.label": "Policy Pages",
    "support.card3.title": "Privacy Policy and Terms of Use",
    "support.card3.meta": "Camera, microphone, and location permissions, on-device retention, and per-store payment and refund terms.",
    "footer.privacy": "Privacy Policy",
    "footer.terms": "Terms of Use",
    "legal.nav.home": "Home",
    "legal.footer.home": "Back to Home",
    "404.eyebrow": "NOT FOUND",
    "404.title": "The requested page could not be found",
    "404.body": "Check the URL or go back to the Provika service home.",
    "404.cta": "Go to Home",
    "terms.eyebrow": "TERMS OF USE",
    "terms.title": "Terms of Use",
    "terms.updated": "Last updated: August 29, 2026",
    "terms.intro": "These terms apply to both the iOS and Android editions of Provika. Where a matter differs by store — payments and refunds in particular — the relevant clause says so explicitly.",
    "terms.section1.title": "1. What Provika is for",
    "terms.section1.body": "Provika is a capture tool that records time, location, and device context alongside media, and produces an evidence package containing a hash of the original and a digital signature. It is not limited to traffic reporting; it can also be used for incident documentation, inspections, delivery and field records. It is not a legal advisory service, does not conduct investigations, and does not guarantee any outcome with an authority.",
    "terms.section2.title": "2. What is and is not guaranteed",
    "terms.section2.body": "Provika provides technical integrity information. A hash helps detect whether media changed after the package was created, and a signature verifies the binding between a key and the canonical claim. Recorded time and location are observations reported by the device and do not by themselves establish truth. Provika does not guarantee that this material will be accepted as evidence by any organization or proceeding, and it does not replace forensic analysis.",
    "terms.section3.title": "3. Your responsibilities",
    "terms.section3.body": "You are responsible for the lawfulness of what you record, keep, share, or report. Follow local law, respect other people's privacy, and do not operate the device while driving or in any unsafe situation. The quick-capture entry points (lock screen shortcut, quick settings tile, volume key, widget) exist to reduce fiddling with the screen — they are not an invitation to operate the app while driving.",
    "terms.section4.title": "4. Platforms and feature differences",
    "terms.section4.body": "The iOS and Android editions share one evidence format and can verify each other's packages. Available features still differ by platform and device. iOS writes a QuickTime container and uses the Secure Enclave; Android writes an MP4 container and uses the Android Keystore (StrongBox or TEE). Hardware key attestation, ultra-wide capture, lock screen entry points, and whether the overlay is burned into stills can vary by device.",
    "terms.section5.title": "5. Payments and refunds",
    "terms.section5.body": "In-app support purchases are made through each store's payment system. Purchases made on the App Store follow Apple's refund process; purchases made on Google Play follow Google Play's refund policy. Support purchases fund development and do not unlock separate features. Please direct refund requests to the store where you purchased.",
    "terms.section6.title": "6. Changes to the app",
    "terms.section6.body": "Features may change, improve, be limited, or be discontinued without prior notice. We will not, however, make a change that renders already-created evidence packages unreadable; when the evidence format changes, existing packages remain verifiable.",
    "terms.section7.title": "7. Intellectual property",
    "terms.section7.body": "Rights in the app, brand, design, copy, and service components belong to the Provika operator or the respective rights holders unless stated otherwise. Media you capture and the evidence packages built from it remain yours.",
    "terms.section8.title": "8. Warranty and liability",
    "terms.section8.body": "The service is provided as is. We do not warrant uninterrupted operation, freedom from error, legal suitability, or fitness for a particular purpose in every environment. To the extent permitted by law, the operator is not liable for indirect or incidental damages arising from use of the service. Nothing in this clause limits rights granted to you by consumer protection law.",
    "terms.section9.title": "9. Contact and notices",
    "terms.section9.body": "Material changes to these terms are published on this page. You can reach us by email or through the GitHub profile below.",
    "privacy.eyebrow": "PRIVACY POLICY",
    "privacy.title": "Privacy Policy",
    "privacy.updated": "Last updated: August 29, 2026",
    "privacy.intro": "This policy applies to both the iOS and Android editions of Provika. In one line: Provika does not collect your data and does not send it to a server.",
    "privacy.section1.title": "1. What we do not collect",
    "privacy.section1.body": "Provika does not create accounts, does not identify users, and does not send your media or location to any server we operate. We have no way to know what you captured. The app has no backend upload capability at all.",
    "privacy.section2.title": "2. What is stored on your device",
    "privacy.section2.body": "The original media, a claim recording capture time, location, and device context, a signature envelope with hashes, an index used to browse the gallery, and your settings are stored in the app's private storage on your device. The signing key is created inside the device's secure hardware and never leaves it.",
    "privacy.section3.title": "3. Why each permission is used",
    "privacy.section3.body": "The camera is used to capture, the microphone to record audio with video, and location to record where a capture happened. On Android we also request notification permission so the recording notification can stay visible. No permission is used for advertising or analytics, and declining one simply removes that capability. Without location permission we do not invent coordinates — we record none.",
    "privacy.section4.title": "4. The only way data leaves your device",
    "privacy.section4.body": "Data leaves your device only when you explicitly export or share it. What happens afterwards is governed by whichever app or service you chose. App data is also excluded from automatic cloud backup and device-to-device transfer, so evidence does not silently follow you to a new phone.",
    "privacy.section5.title": "5. Third parties and analytics",
    "privacy.section5.body": "We do not sell user information or capture data. Release builds ship without an analytics SDK, and the app serves no advertising. If analytics are ever introduced, this policy and the store data-safety disclosure will be updated first.",
    "privacy.section6.title": "6. Retention and deletion",
    "privacy.section6.body": "You decide how long anything is kept. You can delete individual records in the app, or set unreported records to be removed automatically after 30 or 90 days. Uninstalling the app removes its private storage with it. There is no copy on our side to delete.",
    "privacy.section7.title": "7. Security and its limits",
    "privacy.section7.body": "We create SHA-256 hashes and ECDSA P-256 signatures for integrity checking. The signing key lives in the Secure Enclave on iOS and in the Android Keystore (StrongBox where available) on Android. On Android the package can also carry a certificate attesting that the key was created in real secure hardware — a fact about the key, not about what was captured. No approach guarantees absolute security.",
    "privacy.section8.title": "8. Children",
    "privacy.section8.body": "Provika is not directed at children and does not collect personal information from children.",
    "privacy.section9.title": "9. Contact",
    "privacy.section9.body": "Questions about this policy can be sent by email or through the GitHub profile below.",
    "nav.platforms": "iPhone · Android",
    "store.ios.kicker": "Download on the",
    "store.android.kicker": "Coming soon on",
    "platforms.eyebrow": "ONE FORMAT, TWO PLATFORMS",
    "platforms.title": "iPhone and Android verify each other's packages",
    "platforms.body": "Both apps use one evidence format, so a package made on either side is verified by the other. Only the parts that must follow the device differ, and the package records which ones did.",
    "platforms.ios.title": "iOS 18 and later",
    "platforms.ios.item1": "QuickTime container · Secure Enclave signing key",
    "platforms.ios.item2": "One-tap capture from Control Center, Lock Screen, Action button",
    "platforms.ios.item3": "Locked-camera capture extension",
    "platforms.android.title": "Android 10 and later · tuned for Galaxy",
    "platforms.android.item1": "MP4 container · Android Keystore (StrongBox) signing key",
    "platforms.android.item2": "Quick settings tile, home widget, launcher shortcut, volume key",
    "platforms.android.item3": "Guidance for lock screen shortcuts and side-key double press",
    "platforms.android.item4": "Hardware key attestation carried inside the package",
    "platforms.note": "Key attestation states only that the signing key was created in real secure hardware. It says nothing about what was captured, and nothing about legal effect."
  }
};

function applyTranslations(lang) {
  const dictionary = translations[lang] || translations.ko;
  document.documentElement.lang = lang;

  document.querySelectorAll("[data-i18n]").forEach((element) => {
    const key = element.dataset.i18n;
    if (dictionary[key]) {
      element.textContent = dictionary[key];
    }
  });

  document.querySelectorAll("[data-lang-button]").forEach((button) => {
    button.classList.toggle("is-active", button.dataset.langButton === lang);
  });

  const page = document.body.dataset.page || "home";
  const pageMeta = metaByPage[page] || metaByPage.home;
  const nextMeta = pageMeta[lang] || pageMeta.ko;
  document.title = nextMeta.title;

  const metaDescription = document.querySelector('meta[name="description"]');
  if (metaDescription) {
    metaDescription.setAttribute("content", nextMeta.description);
  }

  localStorage.setItem("provika-docs-lang", lang);
}

function resolveInitialLanguage() {
  const saved = localStorage.getItem("provika-docs-lang");
  if (saved && translations[saved]) {
    return saved;
  }

  const params = new URLSearchParams(window.location.search);
  const fromQuery = params.get("lang");
  if (fromQuery && translations[fromQuery]) {
    return fromQuery;
  }

  const browserLanguage = navigator.language || navigator.userLanguage || "en";
  return browserLanguage.toLowerCase().startsWith("ko") ? "ko" : "en";
}

document.addEventListener("DOMContentLoaded", () => {
  const yearElement = document.getElementById("year");
  if (yearElement) {
    yearElement.textContent = new Date().getFullYear();
  }

  const initialLanguage = resolveInitialLanguage();
  applyTranslations(initialLanguage);

  document.querySelectorAll("[data-lang-button]").forEach((button) => {
    button.addEventListener("click", () => applyTranslations(button.dataset.langButton));
  });
});
