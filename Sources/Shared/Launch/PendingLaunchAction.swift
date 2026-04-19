//
//  PendingLaunchAction.swift
//  Provika
//
//  Created by bbdyno on 4/19/26.
//

import SwiftUI

// 외부 트리거(위젯·액션 버튼·단축어)가 앱을 깨웠을 때 수행할 작업을 앱 프로세스 안에서 전달하는 채널.
// AppIntent의 perform()이 openAppWhenRun=true로 앱 프로세스에서 실행되므로, shared 인스턴스에 플래그만 세우고
// RootView/CameraView가 이를 관찰하여 동작한다.
@Observable
final class PendingLaunchAction {
    static let shared = PendingLaunchAction()

    var shouldStartRecording = false

    private init() {}
}
