//
//  LockedCameraControlWidget.swift
//  ProvikaWidgets
//

import AppIntents
import SwiftUI
import WidgetKit

// 잠금 해제 없이 촬영 화면을 여는 컨트롤.
// CameraCaptureIntent 를 쓰므로 기기가 잠겨 있으면 시스템이 잠금 카메라 확장을 띄운다.
struct LockedCameraControlWidget: ControlWidget {
    static let kind: String = "com.bbdyno.app.provika.widgets.lockedCamera"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: ProvikaCameraCaptureIntent()) {
                Label {
                    Text("widget.lockedCamera.title", bundle: .main)
                } icon: {
                    Image(systemName: "camera.viewfinder")
                }
            }
        }
        .displayName("widget.lockedCamera.displayName")
        .description("widget.lockedCamera.description")
    }
}
