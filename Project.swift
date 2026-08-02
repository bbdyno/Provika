import Foundation
import ProjectDescription

// iOS 18+: Control Widget이 지원하는 최소 버전 (잠금화면·제어 센터·액션 버튼 원터치 녹화)
let deploymentTargets: DeploymentTargets = .iOS("18.0")

var appResources: ResourceFileElements = [
    .glob(pattern: "Resources/**", excluding: ["Resources/Widgets/**"])
]

// GoogleService-Info.plist는 로컬 Firebase 설정이며 저장소에 포함하지 않는다.
// 파일이 있는 개발 환경에서만 앱 번들 리소스로 추가한다.
if FileManager.default.fileExists(atPath: "GoogleService-Info.plist") {
    appResources.resources.append(.glob(pattern: "GoogleService-Info.plist"))
}

let project = Project(
    name: "Provika",
    organizationName: "Provika",
    options: .options(
        defaultKnownRegions: ["en", "ko", "zh-Hans", "zh-Hant", "ja"],
        developmentRegion: "en"
    ),
    settings: .settings(
        base: [
            "DEVELOPMENT_TEAM": "M79H9K226Y",
            "MARKETING_VERSION": "2.0",
            "CURRENT_PROJECT_VERSION": "2026.8.2.1",
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
            bundleId: "com.bbdyno.app.provika",
            deploymentTargets: deploymentTargets,
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
                "UIBackgroundModes": ["audio"],
                // English fallback. InfoPlist.xcstrings supplies all five supported locales at runtime.
                "NSCameraUsageDescription": "Provika uses the camera to record traffic violation evidence videos.",
                "NSMicrophoneUsageDescription": "Provika records audio for evidence integrity.",
                "NSLocationWhenInUseUsageDescription": "Provika records GPS coordinates for evidence credibility.",
                "NSPhotoLibraryAddUsageDescription": "Provika can save recorded videos to your photo library."
            ]),
            sources: [
                "Sources/App/**",
                "Sources/Core/**",
                "Sources/Features/**",
                "Sources/Shared/**"
            ],
            resources: appResources,
            dependencies: [
                .target(name: "ProvikaWidgets"),
                .target(name: "ProvikaLockedCapture"),
                .external(name: "FirebaseAnalytics")
            ]
        ),
        .target(
            name: "ProvikaWidgets",
            destinations: .iOS,
            product: .appExtension,
            bundleId: "com.bbdyno.app.provika.widgets",
            deploymentTargets: deploymentTargets,
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Provika Widgets",
                "NSExtension": [
                    "NSExtensionPointIdentifier": "com.apple.widgetkit-extension"
                ]
            ]),
            sources: [
                "Sources/Widgets/**",
                "Sources/Shared/**"
            ],
            resources: [
                "Resources/Widgets/**"
            ],
            dependencies: []
        ),
        .target(
            name: "ProvikaLockedCapture",
            destinations: .iOS,
            product: .extensionKitExtension,
            bundleId: "com.bbdyno.app.provika.locked-capture",
            deploymentTargets: deploymentTargets,
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Provika Camera",
                "EXAppExtensionAttributes": [
                    "EXExtensionPointIdentifier": "com.apple.securecapture"
                ],
                "NSCameraUsageDescription": "Provika uses the camera to create a pending capture for import after unlock.",
                "NSPhotoLibraryUsageDescription": "The simulator fallback can select a photo to exercise the pending import flow."
            ]),
            sources: [
                "Sources/LockedCaptureExtension/**",
                "Sources/Shared/Intents/ProvikaCameraCaptureIntent.swift",
                "Sources/Core/LockedCapture/LockedCapturePolicies.swift"
            ],
            resources: [],
            dependencies: []
        ),
        .target(
            name: "ProvikaTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.bbdyno.app.provika.tests",
            deploymentTargets: deploymentTargets,
            infoPlist: .default,
            sources: ["Tests/**"],
            dependencies: [.target(name: "Provika")]
        )
    ],
    resourceSynthesizers: [
        .strings(),
        .assets(),
        .fonts()
    ]
)
