//
//  PendingLaunchAction.swift
//  Provika
//
//  Created by bbdyno on 4/19/26.
//

import SwiftUI

// 외부 트리거(위젯·액션 버튼·단축어)가 앱을 깨웠을 때 수행할 작업.
// userPreferred 는 "Provika 카메라"처럼 동작이 정해지지 않은 진입점용이며, 앱이 설정값으로 해석한다.
enum LaunchRequest: Equatable {
    case startVideo
    case capturePhoto
    case userPreferred
}

// 외부 트리거가 앱을 깨웠을 때 수행할 작업을 앱 프로세스 안에서 전달하는 채널.
// AppIntent의 perform()이 openAppWhenRun=true로 앱 프로세스에서 실행되므로, shared 인스턴스에 요청만 남기고
// RootView/CameraView가 이를 관찰하여 동작한다.
@Observable
final class PendingLaunchAction {
    static let shared = PendingLaunchAction()

    var request: LaunchRequest?

    private init() {}
}
