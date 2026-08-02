//
//  CameraPreviewView.swift
//  Provika
//
//  Created by bbdyno on 4/16/26.
//

import AVFoundation
import AVKit
import SwiftUI

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    var onTapLocation: ((CGPoint) -> Void)?
    var onPreviewLayerReady: ((AVCaptureVideoPreviewLayer) -> Void)?

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        onPreviewLayerReady?(view.previewLayer)

        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        view.addGestureRecognizer(tapGesture)

        if let physicalControl = ActiveAppPhysicalCaptureControl.registered(for: session) {
            let interaction = physicalControl.makeInteraction()
            view.addInteraction(interaction)
            context.coordinator.captureEventInteraction = interaction
        }

        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        context.coordinator.onTapLocation = onTapLocation
        onPreviewLayerReady?(uiView.previewLayer)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTapLocation: onTapLocation)
    }

    final class Coordinator: NSObject {
        var onTapLocation: ((CGPoint) -> Void)?
        var captureEventInteraction: AVCaptureEventInteraction?

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
