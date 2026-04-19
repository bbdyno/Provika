import ProjectDescription

// iOS 18+: Control Widget이 지원하는 최소 버전 (잠금화면·제어 센터·액션 버튼 원터치 녹화)
let deploymentTargets: DeploymentTargets = .iOS("18.0")

let project = Project(
    name: "Provika",
    organizationName: "Provika",
    options: .options(
        defaultKnownRegions: ["en", "ko"],
        developmentRegion: "en"
    ),
    settings: .settings(
        base: [
            "DEVELOPMENT_TEAM": "M79H9K226Y",
            "MARKETING_VERSION": "1.0.0",
            "CURRENT_PROJECT_VERSION": "2026.04.19.1",
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
                "NSCameraUsageDescription": "$(LOCALIZED:NSCameraUsageDescription)",
                "NSMicrophoneUsageDescription": "$(LOCALIZED:NSMicrophoneUsageDescription)",
                "NSLocationWhenInUseUsageDescription": "$(LOCALIZED:NSLocationWhenInUseUsageDescription)",
                "NSPhotoLibraryAddUsageDescription": "$(LOCALIZED:NSPhotoLibraryAddUsageDescription)"
            ]),
            sources: [
                "Sources/App/**",
                "Sources/Core/**",
                "Sources/Features/**",
                "Sources/Shared/**"
            ],
            resources: [
                .glob(pattern: "Resources/**", excluding: ["Resources/Widgets/**"])
            ],
            dependencies: [
                .target(name: "ProvikaWidgets")
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
