const metaByPage = {
  home: {
    ko: {
      title: "Provika",
      description:
        "Provika는 교통 위반 증거 영상을 촬영하고, 프레임 내 타임스탬프와 GPS, 해시 및 서명 메타데이터를 함께 남기는 iPhone용 증거 캡처 앱입니다."
    },
    en: {
      title: "Provika",
      description:
        "Provika is an iPhone evidence capture app for traffic violations, combining burned-in timestamp and GPS overlays with local integrity metadata and signature verification."
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
  ko: {
    "nav.workflow": "증거 흐름",
    "nav.surfaces": "핵심 화면",
    "nav.trust": "보관과 신뢰",
    "nav.support": "지원",
    "nav.privacy": "개인정보 처리방침",
    "nav.terms": "이용 약관",
    "hero.eyebrow": "ON-DEVICE TRAFFIC EVIDENCE CAPTURE FOR IPHONE",
    "hero.title": "현장에서 바로 남기고, 프레임에 증거를 새기는 교통 위반 기록 앱",
    "hero.body":
      "Provika는 영상에 타임스탬프와 GPS를 직접 기록하고, sidecar JSON, SHA-256 해시, ECDSA 서명, 갤러리 검토 흐름까지 하나로 묶은 iPhone용 증거 캡처 서비스입니다.",
    "hero.primary": "증거 흐름 보기",
    "hero.secondary": "개인정보 처리방침",
    "hero.stat1.label": "기록 방식",
    "hero.stat1.value": "프레임 내 시간·위치 burn-in",
    "hero.stat2.label": "무결성",
    "hero.stat2.value": "SHA-256 + ECDSA 서명",
    "hero.stat3.label": "저장 모델",
    "hero.stat3.value": "기기 로컬 우선 저장",
    "hero.visual.state": "RECORD READY",
    "hero.visual.badge": "Evidence Burn-In",
    "hero.card1.kicker": "LOCAL SIDE CAR",
    "hero.card1.title": "영상과 메타데이터를 같이 남겨서 나중에 다시 검증",
    "hero.card1.body":
      "촬영 후 `.mov`와 함께 위치 이력, 파일 해시, 공개키 정보가 담긴 JSON을 저장해 검토와 공유 시점을 분리합니다.",
    "hero.card2.kicker": "INTEGRITY STATUS",
    "hero.card2.item1": "영상 파일 해시 생성",
    "hero.card2.item2": "서명 키로 무결성 서명",
    "hero.card2.item3": "갤러리에서 다시 검증",
    "hero.card2.status": "READY",
    "workflow.eyebrow": "EVIDENCE WORKFLOW",
    "workflow.title": "기록, 각인, 서명, 검토까지 이어지는 증거 흐름",
    "workflow.body":
      "Provika는 단순 카메라가 아니라 촬영 순간의 시간과 위치를 프레임에 새기고, 별도 메타데이터와 무결성 정보를 함께 보존하는 흐름을 목표로 합니다.",
    "workflow.step1.title": "즉시 촬영",
    "workflow.step1.body": "실시간 카메라 프리뷰와 선녹화 버퍼, 포커스, 줌, 플래시 제어로 현장 기록을 바로 시작합니다.",
    "workflow.step2.title": "프레임 오버레이 각인",
    "workflow.step2.body": "타임스탬프, GPS 좌표, 앱/기기 정보가 녹화 프레임에 직접 합성되어 별도 플레이어 없이도 확인 가능합니다.",
    "workflow.step3.title": "무결성 메타데이터 저장",
    "workflow.step3.body": "녹화 종료 후 해시, 전자서명, 공개키, 위치 트랙을 sidecar JSON으로 저장해 파일 단위 검증이 가능하도록 만듭니다.",
    "workflow.step4.title": "갤러리에서 검토와 공유",
    "workflow.step4.body": "날짜별 필터링, 재생, 공유, 신고 완료 표시, 삭제와 함께 서명 검증 상태를 다시 확인할 수 있습니다.",
    "surfaces.eyebrow": "KEY SURFACES",
    "surfaces.title": "교통 위반 기록 앱에 필요한 핵심 화면을 하나의 서비스 경험으로",
    "surfaces.card1.kicker": "Capture",
    "surfaces.card1.title": "현장 촬영에 집중한 카메라 탭",
    "surfaces.card1.body": "세로 중심 UI, 아이폰 스타일 줌 다이얼, 빠른 녹화 흐름으로 순간 대응이 가능합니다.",
    "surfaces.card2.kicker": "Widget Trigger",
    "surfaces.card2.title": "잠금화면과 제어 센터에서 빠르게 진입",
    "surfaces.card2.body": "Control Widget을 통해 앱을 열고 즉시 녹화를 시작하는 빠른 진입점을 제공합니다.",
    "surfaces.card3.kicker": "Review",
    "surfaces.card3.title": "갤러리와 상세 검토 흐름",
    "surfaces.card3.body": "저장된 녹화물을 날짜별로 정리하고, 재생과 공유, 신고 완료 표시, 서명 검증까지 한 화면에서 확인합니다.",
    "surfaces.card4.kicker": "Settings",
    "surfaces.card4.title": "기록 정책과 보안 키 관리",
    "surfaces.card4.body": "선녹화 시간, 오버레이, 저장 정책, 공개키 확인과 서명 키 재생성 같은 관리 기능을 제공합니다.",
    "trust.eyebrow": "LOCAL-FIRST TRUST MODEL",
    "trust.title": "기기 안에 남기고, 사용자가 직접 공유할 때만 밖으로 나갑니다",
    "trust.card1.kicker": "ON DEVICE",
    "trust.card1.title": "현재 구현에는 서버 업로드 흐름이 없습니다",
    "trust.card1.body":
      "영상, 메타데이터, 해시, 서명 정보는 기기 로컬에 저장됩니다. 데이터가 기기 밖으로 나가는 시점은 사용자가 직접 공유를 실행할 때입니다.",
    "trust.card1.item1": "녹화 파일과 sidecar JSON 로컬 저장",
    "trust.card1.item2": "실기기에서는 가능할 경우 Secure Enclave 기반 키 사용",
    "trust.card1.item3": "갤러리에서 저장된 서명 상태 재검증",
    "trust.card2.kicker": "WHEN DATA LEAVES",
    "trust.card2.title": "사용자가 내보낼 때만 전송",
    "trust.card2.body": "공유 시트, 파일 내보내기 등 사용자가 선택한 동작을 통해서만 외부 전송이 일어납니다.",
    "trust.card3.kicker": "CURRENT STATUS",
    "trust.card3.title": "현재는 동작하는 iOS 프로토타입",
    "trust.card3.body": "촬영, 오버레이 합성, 저장, 해시/서명, 갤러리 검토까지 로컬 엔드 투 엔드 흐름이 구현돼 있습니다.",
    "support.eyebrow": "SUPPORT & LEGAL",
    "support.title": "프로젝트 정보와 정책 문서",
    "support.body": "기술 진행 상황은 GitHub 저장소에서 확인할 수 있고, 정책 문서는 이 페이지에서 한국어와 영어로 제공합니다.",
    "support.card1.label": "GitHub 저장소",
    "support.card1.meta": "프로토타입 코드와 프로젝트 구조를 확인할 수 있습니다.",
    "support.card2.label": "이슈 및 문의",
    "support.card2.meta": "버그 리포트나 문의를 남길 수 있는 공개 채널입니다.",
    "support.card3.label": "정책 문서",
    "support.card3.title": "개인정보 처리방침과 이용 약관",
    "support.card3.meta": "카메라, 위치, 로컬 저장, 공유 정책 기준을 문서로 제공합니다.",
    "footer.privacy": "개인정보 처리방침",
    "footer.terms": "이용 약관",
    "legal.nav.home": "홈",
    "legal.footer.home": "홈으로",
    "privacy.eyebrow": "PRIVACY POLICY",
    "privacy.title": "개인정보 처리방침",
    "privacy.updated": "최종 업데이트: 2026년 4월 19일",
    "privacy.section1.title": "1. 수집하는 정보",
    "privacy.section1.body":
      "Provika는 녹화 영상, 영상에 대응하는 sidecar JSON 메타데이터, 앱 설정, 위치 이력, 해시와 서명 검증에 필요한 정보를 기기 안에 저장할 수 있습니다. 카메라, 마이크, 위치, 사진 라이브러리 접근은 기능 제공을 위해서만 사용됩니다.",
    "privacy.section2.title": "2. 정보 사용 목적",
    "privacy.section2.body":
      "수집되거나 생성된 정보는 교통 위반 증거 촬영, 프레임 내 타임스탬프 및 GPS 오버레이, 로컬 무결성 검증, 갤러리 조회, 사용자 설정 유지 기능을 제공하기 위해서만 사용됩니다.",
    "privacy.section3.title": "3. 저장 및 외부 전송",
    "privacy.section3.body":
      "현재 구현에는 백엔드 업로드 기능이 없습니다. 영상과 메타데이터는 기본적으로 사용자의 기기에 로컬 저장되며, 사용자가 공유 기능을 직접 실행하는 경우에만 데이터가 기기 밖으로 전송될 수 있습니다.",
    "privacy.section4.title": "4. 제3자 제공",
    "privacy.section4.body":
      "Provika 운영자는 사용자의 개인정보나 녹화 데이터를 판매하지 않으며, 법적 의무가 있거나 사용자가 직접 공유를 선택한 경우를 제외하고 제3자에게 제공하지 않습니다.",
    "privacy.section5.title": "5. 보관과 삭제",
    "privacy.section5.body":
      "사용자는 앱 내 삭제 기능, 앱 제거, 기기 설정을 통해 저장된 영상과 메타데이터를 삭제할 수 있습니다. 앱 권한은 iOS 설정에서 언제든지 변경하거나 철회할 수 있습니다.",
    "privacy.section6.title": "6. 보안",
    "privacy.section6.body":
      "무결성 검증을 위해 파일 해시와 전자서명이 생성될 수 있으며, 실기기에서는 가능할 경우 Secure Enclave 기반 키를 사용합니다. 다만 어떤 저장 방식도 절대적인 보안을 보장하지는 않습니다.",
    "privacy.section7.title": "7. 문의",
    "privacy.section7.body":
      "본 정책에 대한 문의는 GitHub 저장소 또는 이슈 페이지를 통해 접수할 수 있습니다. 공식 연락 채널이 추가되면 이 페이지에 반영됩니다.",
    "terms.eyebrow": "TERMS OF USE",
    "terms.title": "이용 약관",
    "terms.updated": "최종 업데이트: 2026년 4월 19일",
    "terms.section1.title": "1. 서비스 목적",
    "terms.section1.body":
      "Provika는 교통 위반 장면을 기록하고 관련 메타데이터를 함께 보관하기 위한 증거 캡처 도구입니다. 법률 자문, 수사 대행, 또는 공공기관 제출 결과를 보장하는 서비스는 아닙니다.",
    "terms.section2.title": "2. 사용자 책임",
    "terms.section2.body":
      "사용자는 현지 법규와 안전 수칙을 준수해야 하며, 운전 중 또는 위험한 상황에서 앱을 부주의하게 사용해서는 안 됩니다. 촬영과 공유, 신고 절차의 적법성 판단 책임은 사용자에게 있습니다.",
    "terms.section3.title": "3. 기록과 증거 활용",
    "terms.section3.body":
      "Provika는 영상, 타임스탬프, 위치 정보, 해시, 전자서명 같은 보조 수단을 제공하지만, 특정 기관이나 절차에서 해당 자료가 증거로 채택되거나 인정될 것이라고 보증하지 않습니다.",
    "terms.section4.title": "4. 기능 변경",
    "terms.section4.body":
      "서비스 기능은 사전 공지 없이 변경, 개선, 제한 또는 중단될 수 있습니다. 프로토타입 단계에서는 UI와 저장 정책, 검증 방식이 더 자주 바뀔 수 있습니다.",
    "terms.section5.title": "5. 지식재산권",
    "terms.section5.body":
      "앱, 브랜드, 디자인, 문구, 코드 및 서비스 구성 요소에 대한 권리는 별도 명시가 없는 한 Provika 운영자 또는 해당 권리자에게 귀속됩니다.",
    "terms.section6.title": "6. 보증 제한과 책임 한도",
    "terms.section6.body":
      "서비스는 현 상태 그대로 제공되며, 모든 환경에서 무중단 동작, 오류 없음, 법적 적합성 또는 특정 목적 적합성을 보증하지 않습니다. 법이 허용하는 범위에서 운영자는 서비스 사용으로 인한 간접적 손해에 대해 책임을 지지 않습니다.",
    "terms.section7.title": "7. 문의 및 고지",
    "terms.section7.body":
      "본 약관의 중요한 변경 사항은 이 페이지에 반영됩니다. 문의는 GitHub 저장소 또는 이슈 페이지를 통해 받을 수 있습니다.",
    "404.eyebrow": "NOT FOUND",
    "404.title": "요청한 페이지를 찾을 수 없습니다",
    "404.body": "주소를 다시 확인하거나 Provika 서비스 홈으로 이동해 주세요.",
    "404.cta": "홈으로 이동"
  },
  en: {
    "nav.workflow": "Workflow",
    "nav.surfaces": "Surfaces",
    "nav.trust": "Trust",
    "nav.support": "Support",
    "nav.privacy": "Privacy Policy",
    "nav.terms": "Terms of Use",
    "hero.eyebrow": "ON-DEVICE TRAFFIC EVIDENCE CAPTURE FOR IPHONE",
    "hero.title": "Capture the scene immediately and burn the proof directly into every frame",
    "hero.body":
      "Provika is an iPhone evidence capture service for traffic violations, combining burned-in timestamp and GPS overlays with sidecar JSON metadata, SHA-256 hashing, ECDSA signing, and a reviewable gallery flow.",
    "hero.primary": "See the Workflow",
    "hero.secondary": "Privacy Policy",
    "hero.stat1.label": "Capture Method",
    "hero.stat1.value": "Timestamp and GPS burned into frames",
    "hero.stat2.label": "Integrity",
    "hero.stat2.value": "SHA-256 + ECDSA signature",
    "hero.stat3.label": "Storage Model",
    "hero.stat3.value": "Local-first on-device storage",
    "hero.visual.state": "RECORD READY",
    "hero.visual.badge": "Evidence Burn-In",
    "hero.card1.kicker": "LOCAL SIDE CAR",
    "hero.card1.title": "Store the video with matching metadata so it can be reviewed later",
    "hero.card1.body":
      "After recording, Provika stores the `.mov` file with a JSON sidecar containing location history, file hash, and public-key related integrity information.",
    "hero.card2.kicker": "INTEGRITY STATUS",
    "hero.card2.item1": "Generate file hash",
    "hero.card2.item2": "Sign integrity payload",
    "hero.card2.item3": "Re-verify in gallery",
    "hero.card2.status": "READY",
    "workflow.eyebrow": "EVIDENCE WORKFLOW",
    "workflow.title": "A single chain from capture to burn-in, signing, and review",
    "workflow.body":
      "Provika is more than a camera. It is designed to preserve the capture moment with on-frame timestamp and GPS overlays while keeping separate metadata and integrity records together.",
    "workflow.step1.title": "Record immediately",
    "workflow.step1.body": "Use the live camera preview, pre-record buffer, focus, zoom, and flash controls to start documenting the scene without delay.",
    "workflow.step2.title": "Burn overlay into frames",
    "workflow.step2.body": "Timestamp, GPS coordinates, and app or device footer text are composited directly into recorded frames.",
    "workflow.step3.title": "Store integrity metadata",
    "workflow.step3.body": "After recording ends, Provika saves file hash, digital signature, public key, and location track into a sidecar JSON for file-level verification.",
    "workflow.step4.title": "Review and share from the gallery",
    "workflow.step4.body": "Users can filter by date, play back recordings, share files, mark reports, delete items, and re-check signature validity.",
    "surfaces.eyebrow": "KEY SURFACES",
    "surfaces.title": "The core screens needed for a traffic evidence workflow",
    "surfaces.card1.kicker": "Capture",
    "surfaces.card1.title": "A camera tab optimized for field recording",
    "surfaces.card1.body": "Portrait-first UI, an iPhone-style zoom dial, and a fast record flow help the user react quickly on site.",
    "surfaces.card2.kicker": "Widget Trigger",
    "surfaces.card2.title": "Fast entry from the lock screen and Control Center",
    "surfaces.card2.body": "A Control Widget can open the app and trigger immediate recording as a quick-start entry point.",
    "surfaces.card3.kicker": "Review",
    "surfaces.card3.title": "Gallery and detail review flow",
    "surfaces.card3.body": "Saved recordings can be organized by date, reviewed, shared, marked as reported, and checked for signature validity.",
    "surfaces.card4.kicker": "Settings",
    "surfaces.card4.title": "Capture policy and signing-key management",
    "surfaces.card4.body": "Users can manage pre-record duration, overlays, storage behavior, public key visibility, and signing-key regeneration.",
    "trust.eyebrow": "LOCAL-FIRST TRUST MODEL",
    "trust.title": "Data stays on the device unless the user explicitly exports it",
    "trust.card1.kicker": "ON DEVICE",
    "trust.card1.title": "There is no backend upload flow in the current implementation",
    "trust.card1.body":
      "Video files, metadata, hashes, and signatures are stored locally on the device. Data leaves the device only when the user explicitly chooses to share or export it.",
    "trust.card1.item1": "Recordings and sidecar JSON stored locally",
    "trust.card1.item2": "Secure Enclave-backed key when available on real devices",
    "trust.card1.item3": "Stored signatures can be re-verified in the gallery",
    "trust.card2.kicker": "WHEN DATA LEAVES",
    "trust.card2.title": "Only through user-initiated export",
    "trust.card2.body": "External transfer happens only through explicit user actions such as the share sheet or file export.",
    "trust.card3.kicker": "CURRENT STATUS",
    "trust.card3.title": "A working iOS prototype today",
    "trust.card3.body": "The current prototype already supports local end-to-end capture, overlay composition, storage, hashing, signing, and gallery review.",
    "support.eyebrow": "SUPPORT & LEGAL",
    "support.title": "Project information and policy pages",
    "support.body": "Technical progress is visible in the GitHub repository, and the policy documents are provided here in Korean and English.",
    "support.card1.label": "GitHub Repository",
    "support.card1.meta": "Browse the prototype codebase and project structure.",
    "support.card2.label": "Issues and Contact",
    "support.card2.meta": "Use the public issue tracker for bug reports or questions.",
    "support.card3.label": "Policy Pages",
    "support.card3.title": "Privacy Policy and Terms of Use",
    "support.card3.meta": "Review the rules for camera, location, local storage, and sharing behavior.",
    "footer.privacy": "Privacy Policy",
    "footer.terms": "Terms of Use",
    "legal.nav.home": "Home",
    "legal.footer.home": "Back to Home",
    "privacy.eyebrow": "PRIVACY POLICY",
    "privacy.title": "Privacy Policy",
    "privacy.updated": "Last updated: April 19, 2026",
    "privacy.section1.title": "1. Information We Collect",
    "privacy.section1.body":
      "Provika may store recorded videos, matching sidecar JSON metadata, app settings, location history, and information required for hash and signature verification on the user's device. Camera, microphone, location, and photo library access are used only to provide core functionality.",
    "privacy.section2.title": "2. How Information Is Used",
    "privacy.section2.body":
      "Information collected or generated by the app is used only to provide traffic evidence capture, burned-in timestamp and GPS overlays, local integrity verification, gallery review, and persisted user settings.",
    "privacy.section3.title": "3. Storage and External Transfer",
    "privacy.section3.body":
      "There is no backend upload feature in the current implementation. Videos and metadata are stored locally on the user's device by default and may leave the device only when the user explicitly chooses to share or export them.",
    "privacy.section4.title": "4. Sharing With Third Parties",
    "privacy.section4.body":
      "The operator of Provika does not sell personal information or recorded data and does not share them with third parties except where legally required or when the user directly initiates sharing.",
    "privacy.section5.title": "5. Retention and Deletion",
    "privacy.section5.body":
      "Users can delete stored videos and metadata through in-app deletion, app removal, or device settings. App permissions can also be changed or revoked at any time in iOS settings.",
    "privacy.section6.title": "6. Security",
    "privacy.section6.body":
      "Provika may generate file hashes and digital signatures for integrity verification and, on real devices, may use Secure Enclave-backed keys when available. No storage mechanism can guarantee absolute security.",
    "privacy.section7.title": "7. Contact",
    "privacy.section7.body":
      "Questions about this policy may be submitted through the GitHub repository or issue tracker. If an additional official contact channel is introduced, this page will be updated.",
    "terms.eyebrow": "TERMS OF USE",
    "terms.title": "Terms of Use",
    "terms.updated": "Last updated: April 19, 2026",
    "terms.section1.title": "1. Service Purpose",
    "terms.section1.body":
      "Provika is an evidence capture tool designed to record traffic violation scenes and preserve related metadata. It is not legal advice, an investigative service, or a guarantee that submitted material will be accepted by any authority.",
    "terms.section2.title": "2. User Responsibility",
    "terms.section2.body":
      "Users must comply with applicable local laws and safety rules and must not use the app carelessly while driving or in unsafe conditions. Users are responsible for the legality of recording, sharing, and reporting actions.",
    "terms.section3.title": "3. Recording and Evidence Use",
    "terms.section3.body":
      "Provika provides supporting mechanisms such as video capture, timestamps, location data, hashes, and digital signatures, but does not guarantee that any authority or process will accept those materials as evidence.",
    "terms.section4.title": "4. Feature Changes",
    "terms.section4.body":
      "Features may be changed, improved, limited, or discontinued without prior notice. During the prototype phase, UI, storage policy, and verification behavior may change more frequently.",
    "terms.section5.title": "5. Intellectual Property",
    "terms.section5.body":
      "Unless otherwise stated, rights to the app, brand, design, copy, code, and service components belong to the operator of Provika or the relevant rights holders.",
    "terms.section6.title": "6. Warranty Disclaimer and Limitation of Liability",
    "terms.section6.body":
      "The service is provided as is and without guarantees of uninterrupted operation, absence of errors, legal suitability, or fitness for a particular purpose. To the extent permitted by law, the operator is not liable for indirect damages arising from use of the service.",
    "terms.section7.title": "7. Notices and Contact",
    "terms.section7.body":
      "Material changes to these terms will be reflected on this page. Questions may be submitted through the GitHub repository or issue tracker.",
    "404.eyebrow": "NOT FOUND",
    "404.title": "The requested page could not be found",
    "404.body": "Check the URL or go back to the Provika service home.",
    "404.cta": "Go to Home"
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
