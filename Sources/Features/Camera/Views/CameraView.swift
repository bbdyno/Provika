import SwiftUI

struct CameraView: View {
    @State private var viewModel = CameraViewModel()
    @State private var pinchStartZoom: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.cameraPermissionGranted {
                cameraContent
            } else {
                permissionDeniedView
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }

    private var cameraContent: some View {
        ZStack {
            CameraPreviewView(
                session: viewModel.captureService.session,
                onTapLocation: { point in
                    viewModel.handleTapFocus(at: point)
                }
            )
            .ignoresSafeArea()
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        viewModel.handlePinchZoom(
                            scale: value.magnification,
                            initialZoom: pinchStartZoom
                        )
                    }
                    .onEnded { _ in
                        pinchStartZoom = viewModel.captureService.currentZoomFactor
                    }
            )
            .onAppear {
                pinchStartZoom = viewModel.captureService.currentZoomFactor
            }

            CameraControlsView(
                isFlashOn: viewModel.isFlashOn,
                zoomFactor: viewModel.captureService.currentZoomFactor,
                onFlashToggle: { viewModel.toggleFlash() },
                onGalleryTap: { }
            )
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text(ProvikaStrings.Localizable.Camera.Permission.Denied.title)
                .font(.title2)
                .foregroundStyle(.white)

            Text(ProvikaStrings.Localizable.Camera.Permission.Denied.message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(ProvikaStrings.Localizable.Settings.title) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }
}
