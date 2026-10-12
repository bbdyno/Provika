import AVFoundation
import AVKit
import LockedCameraCapture
import SwiftUI
import UIKit

struct LockedCaptureView: View {
    @State private var camera: LockedCaptureCameraModel

    init(session: LockedCameraCaptureSession) {
        _camera = State(initialValue: LockedCaptureCameraModel(sessionContentURL: session.sessionContentURL))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.status == .cameraUnavailable {
                Text("locked.status.cameraUnavailable", bundle: .main)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                LockedCapturePreview(session: camera.session)
                    .ignoresSafeArea()
                    // 볼륨·카메라 컨트롤 버튼은 앱과 같이 영상 시작/정지로 쓴다.
                    .onCameraCaptureEvent { event in
                        if event.phase == .ended {
                            camera.toggleRecording()
                        }
                    }

                if camera.isRecording {
                    Rectangle()
                        .stroke(.red, lineWidth: 4)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                VStack(spacing: 12) {
                    Text(statusKey, bundle: .main)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(.top, 12)

                    Spacer()

                    Text("locked.notice.sealAfterUnlock", bundle: .main)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 24)

                    controls
                }
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }

    private var controls: some View {
        ZStack {
            recordButton

            HStack {
                Button(action: { camera.capturePhoto() }) {
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                }
                .accessibilityLabel(Text("locked.photo.label", bundle: .main))
                .accessibilityIdentifier("lockedCapturePhotoButton")

                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .padding(.bottom, 24)
    }

    private var recordButton: some View {
        Button(action: { camera.toggleRecording() }) {
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 4)
                    .frame(width: 72, height: 72)

                if camera.isRecording {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.red)
                        .frame(width: 30, height: 30)
                } else {
                    Circle()
                        .fill(.red)
                        .frame(width: 60, height: 60)
                }
            }
        }
        .accessibilityLabel(
            Text(camera.isRecording ? "locked.record.stop" : "locked.record.start", bundle: .main)
        )
        .accessibilityIdentifier("lockedCaptureRecordButton")
    }

    private var statusKey: LocalizedStringKey {
        switch camera.status {
        case .ready: "locked.status.ready"
        case .recording: "locked.status.recording"
        case .saved: "locked.status.saved"
        case .failed: "locked.status.failed"
        case .cameraUnavailable: "locked.status.cameraUnavailable"
        }
    }
}

private struct LockedCapturePreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
