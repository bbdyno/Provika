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
            "DEVELOPMENT_TEAM": "M79H9K226Y",
            "MARKETING_VERSION": "1.0.0",
            "CURRENT_PROJECT_VERSION": "1",
            "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
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
            deploymentTargets: .iOS("17.0"),
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
            bundleId: "com.bbdyno.app.provika.tests",
            deploymentTargets: .iOS("17.0"),
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
