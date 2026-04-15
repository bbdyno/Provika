import AVFoundation
import SwiftUI

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    var onTapLocation: ((CGPoint) -> Void)?

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill

        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        view.addGestureRecognizer(tapGesture)

        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        context.coordinator.onTapLocation = onTapLocation
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTapLocation: onTapLocation)
    }

    final class Coordinator: NSObject {
        var onTapLocation: ((CGPoint) -> Void)?

        init(onTapLocation: ((CGPoint) -> Void)?) {
            self.onTapLocation = onTapLocation
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? PreviewUIView else { return }
            let location = gesture.location(in: view)
            let devicePoint = view.previewLayer.captureDevicePointConverted(
                fromLayerPoint: location
            )
            onTapLocation?(devicePoint)
        }
    }
}

final class PreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
