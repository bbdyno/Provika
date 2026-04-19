//
//  LaunchCameraControlWidget.swift
//  ProvikaWidgets
//
//  Created by bbdyno on 4/19/26.
//

import AppIntents
import SwiftUI
import WidgetKit

// iOS 18+ Control Widget.
// 제어 센터 / 잠금화면 / 액션 버튼에 배치 가능.
// 탭하면 StartRecordingIntent가 실행되어 앱이 열리고 즉시 녹화가 시작된다.
struct LaunchCameraControlWidget: ControlWidget {
    static let kind: String = "com.bbdyno.app.provika.widgets.launchCamera"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: StartRecordingIntent()) {
                Label {
                    Text("widget.launchCamera.title", bundle: .main)
                } icon: {
                    Image("WidgetRecordIcon", bundle: .module)
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                }
            }
        }
        .displayName("widget.launchCamera.displayName")
        .description("widget.launchCamera.description")
    }
}
