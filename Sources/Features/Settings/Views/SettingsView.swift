import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @State private var showPublicKey = false

    var body: some View {
        NavigationStack {
            Form {
                // 녹화
                Section(ProvikaStrings.Localizable.Settings.Section.recording) {
                    Picker(ProvikaStrings.Localizable.Settings.quality, selection: $viewModel.videoQuality) {
                        ForEach(SettingsViewModel.VideoQuality.allCases, id: \.self) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }

                    Picker(ProvikaStrings.Localizable.Settings.codec, selection: $viewModel.codec) {
                        ForEach(SettingsViewModel.VideoCodec.allCases, id: \.self) { codec in
                            Text(codec.rawValue).tag(codec)
                        }
                    }

                    Picker(ProvikaStrings.Localizable.Settings.preRecord, selection: $viewModel.preRecordDuration) {
                        ForEach(SettingsViewModel.PreRecordDuration.allCases, id: \.self) { duration in
                            Text(duration.displayName).tag(duration)
                        }
                    }
                }

                // 저장소
                Section(ProvikaStrings.Localizable.Settings.Section.storage) {
                    Picker(ProvikaStrings.Localizable.Settings.autoDelete, selection: $viewModel.autoDeletePolicy) {
                        ForEach(SettingsViewModel.AutoDeletePolicy.allCases, id: \.self) { policy in
                            Text(policy.displayName).tag(policy)
                        }
                    }
                }

                // 오버레이
                Section(ProvikaStrings.Localizable.Settings.Section.overlay) {
                    Toggle(ProvikaStrings.Localizable.Settings.Overlay.timestamp, isOn: $viewModel.showTimestamp)
                    Toggle(ProvikaStrings.Localizable.Settings.Overlay.location, isOn: $viewModel.showLocation)
                    Toggle(ProvikaStrings.Localizable.Settings.Overlay.device, isOn: $viewModel.showDeviceInfo)
                }

                // 보안
                Section(ProvikaStrings.Localizable.Settings.Section.security) {
                    Button(ProvikaStrings.Localizable.Settings.PublicKey.show) {
                        viewModel.loadPublicKey()
                        showPublicKey = true
                    }

                    Button(ProvikaStrings.Localizable.Settings.SigningKey.regenerate, role: .destructive) {
                        viewModel.showRegenerateKeyAlert = true
                    }
                }

                // 정보
                Section(ProvikaStrings.Localizable.Settings.Section.about) {
                    HStack {
                        Text(ProvikaStrings.Localizable.Settings.version)
                        Spacer()
                        Text(viewModel.appVersion)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(ProvikaStrings.Localizable.Settings.title)
            .sheet(isPresented: $showPublicKey) {
                publicKeySheet
            }
            .alert("서명 키 재생성", isPresented: $viewModel.showRegenerateKeyAlert) {
                Button(ProvikaStrings.Localizable.Common.cancel, role: .cancel) {}
                Button("재생성", role: .destructive) {
                    viewModel.regenerateKey()
                }
            } message: {
                Text("기존 키로 서명된 영상의 검증이 불가능해집니다. 계속하시겠습니까?")
            }
        }
    }

    private var publicKeySheet: some View {
        NavigationStack {
            ScrollView {
                Text(viewModel.publicKeyPEM)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
            }
            .navigationTitle(ProvikaStrings.Localizable.Settings.PublicKey.show)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ProvikaStrings.Localizable.Common.ok) {
                        showPublicKey = false
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        UIPasteboard.general.string = viewModel.publicKeyPEM
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
        }
    }
}
