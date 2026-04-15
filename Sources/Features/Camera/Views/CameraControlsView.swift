import SwiftUI

struct CameraControlsView: View {
    let isFlashOn: Bool
    let zoomFactor: CGFloat
    let onFlashToggle: () -> Void
    let onGalleryTap: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // 줌 레벨 표시
            Text(String(format: "%.1fx", zoomFactor))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(.black.opacity(0.5))
                .clipShape(Capsule())

            Spacer()

            // 하단 컨트롤
            HStack {
                // 갤러리 버튼
                Button(action: onGalleryTap) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                }

                Spacer()

                // 플래시 버튼
                Button(action: onFlashToggle) {
                    Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash")
                        .font(.title2)
                        .foregroundStyle(isFlashOn ? .yellow : .white)
                        .frame(width: 50, height: 50)
                }
            }
            .padding(.horizontal, 40)
        }
        .padding(.vertical, 20)
    }
}
