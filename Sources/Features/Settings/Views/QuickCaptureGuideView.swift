//
//  QuickCaptureGuideView.swift
//  Provika
//

import SwiftUI

// 동작 버튼·제어 센터·잠금 화면 등은 앱이 대신 지정할 수 없으므로 사용자가 직접 설정하는 방법을 안내한다.
struct QuickCaptureGuideView: View {
    private typealias Strings = ProvikaStrings.Localizable.Settings.QuickCapture.Guide

    private struct Item: Identifiable {
        let id: String
        let systemImage: String
        let title: String
        let body: String
    }

    private var items: [Item] {
        [
            Item(id: "actionButton", systemImage: "button.vertical.left.press",
                 title: Strings.ActionButton.title, body: Strings.ActionButton.body),
            Item(id: "controlCenter", systemImage: "switch.2",
                 title: Strings.ControlCenter.title, body: Strings.ControlCenter.body),
            Item(id: "lockScreen", systemImage: "lock.iphone",
                 title: Strings.LockScreen.title, body: Strings.LockScreen.body),
            Item(id: "cameraControl", systemImage: "camera.shutter.button",
                 title: Strings.CameraControl.title, body: Strings.CameraControl.body),
            Item(id: "siri", systemImage: "mic.circle",
                 title: Strings.Siri.title, body: Strings.Siri.body)
        ]
    }

    var body: some View {
        List {
            Section {
                ForEach(items) { item in
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.headline)
                            Text(item.body)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: item.systemImage)
                            .foregroundStyle(.red)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text(Strings.intro)
                    .textCase(nil)
            } footer: {
                Text(Strings.lockedNote)
            }
        }
        .navigationTitle(Strings.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
