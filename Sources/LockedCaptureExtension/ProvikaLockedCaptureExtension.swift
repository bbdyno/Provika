import ExtensionKit
import LockedCameraCapture
import SwiftUI

@main
struct ProvikaLockedCaptureExtension: LockedCameraCaptureExtension {
    var body: some LockedCameraCaptureExtensionScene {
        LockedCameraCaptureUIScene { session in
            LockedCaptureView(session: session)
        }
    }
}
