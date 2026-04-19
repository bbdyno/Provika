// swift-tools-version: 5.9
import PackageDescription

#if TUIST
import ProjectDescription

let packageSettings = PackageSettings(
    // 필요 시 특정 Firebase 모듈을 staticFramework로 고정 (기본: dynamic)
    productTypes: [:]
)
#endif

let package = Package(
    name: "Provika",
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "11.0.0")
    ]
)
