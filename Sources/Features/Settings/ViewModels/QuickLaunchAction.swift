//
//  QuickLaunchAction.swift
//  Provika
//

import Foundation

// "Provika 카메라" 컨트롤처럼 동작이 정해지지 않은 진입점으로 앱이 열렸을 때 할 일.
enum QuickLaunchAction: String, CaseIterable {
    case startVideo
    case capturePhoto
    case openCamera

    static let defaultsKey = "quickLaunchAction"

    static func preferred(in defaults: UserDefaults = .standard) -> QuickLaunchAction {
        QuickLaunchAction(rawValue: defaults.string(forKey: defaultsKey) ?? "") ?? .startVideo
    }

    // 이름이 붙은 인텐트(녹화 시작·사진 촬영)는 설정과 무관하게 이름대로 동작한다.
    static func resolve(_ request: LaunchRequest, defaults: UserDefaults = .standard) -> QuickLaunchAction {
        switch request {
        case .startVideo: .startVideo
        case .capturePhoto: .capturePhoto
        case .userPreferred: preferred(in: defaults)
        }
    }

    var displayName: String {
        switch self {
        case .startVideo: ProvikaStrings.Localizable.Settings.QuickLaunch.Action.startVideo
        case .capturePhoto: ProvikaStrings.Localizable.Settings.QuickLaunch.Action.capturePhoto
        case .openCamera: ProvikaStrings.Localizable.Settings.QuickLaunch.Action.openCamera
        }
    }
}
