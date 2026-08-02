import LockedCameraCapture
import SwiftUI
import UIKit

struct LockedCaptureView: View {
    let session: LockedCameraCaptureSession
    @State private var showingCamera = false
    @State private var status = "Ready"

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.fill").font(.system(size: 48))
            Text(status)
            Button("Capture photo") { showingCamera = true }
                .buttonStyle(.borderedProminent)
        }
        .fullScreenCover(isPresented: $showingCamera) {
            LockedPhotoPicker { data in
                do {
                    _ = try LockedCapturePendingHandoffWriter.publish(
                        mediaData: data,
                        fileExtension: "jpg",
                        mediaType: "image/jpeg",
                        to: session.sessionContentURL
                    )
                    status = "Saved for import"
                } catch {
                    status = "Capture could not be saved"
                }
                showingCamera = false
            } onCancel: {
                showingCamera = false
            }
        }
    }
}

private struct LockedPhotoPicker: UIViewControllerRepresentable {
    let onPhoto: (Data) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.mediaTypes = ["public.image"]
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: LockedPhotoPicker
        init(parent: LockedPhotoPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.96) else {
                parent.onCancel()
                return
            }
            parent.onPhoto(data)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.onCancel() }
    }
}
