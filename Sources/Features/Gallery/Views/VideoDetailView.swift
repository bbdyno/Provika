import AVKit
import SwiftData
import SwiftUI

struct VideoDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let recording: Recording

    @State private var player: AVPlayer?
    @State private var metadata: RecordingMetadata?
    @State private var showDeleteConfirm = false
    @State private var signatureValid: Bool?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 비디오 플레이어
                if let player {
                    VideoPlayer(player: player)
                        .aspectRatio(16/9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .aspectRatio(16/9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            ProgressView()
                        }
                }

                // 메타데이터 카드
                metadataCard

                // 무결성 카드
                integrityCard

                // 액션 버튼
                actionButtons
            }
            .padding()
        }
        .navigationTitle(recording.id)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadContent() }
        .onDisappear { player?.pause() }
        .alert(
            ProvikaStrings.Localizable.Common.delete,
            isPresented: $showDeleteConfirm
        ) {
            Button(ProvikaStrings.Localizable.Common.cancel, role: .cancel) {}
            Button(ProvikaStrings.Localizable.Common.delete, role: .destructive) {
                deleteRecording()
            }
        } message: {
            Text(ProvikaStrings.Localizable.Gallery.Detail.Delete.confirm)
        }
    }

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(recording.createdAt, style: .date)
                + Text(" ")
                + Text(recording.createdAt, style: .time)
            } icon: {
                Image(systemName: "calendar")
            }
            .font(.system(.body, design: .monospaced))

            Label {
                Text(String(format: "%.1f s", recording.duration))
            } icon: {
                Image(systemName: "timer")
            }
            .font(.system(.body, design: .monospaced))

            if let lat = recording.startLatitude, let lng = recording.startLongitude {
                Label {
                    Text(String(format: "%.4f, %.4f", lat, lng))
                } icon: {
                    Image(systemName: "location")
                }
                .font(.system(.body, design: .monospaced))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var integrityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ProvikaStrings.Localizable.Gallery.Detail.hash)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(recording.fileHash)
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)

            if let valid = signatureValid {
                HStack {
                    Image(systemName: valid ? "checkmark.shield.fill" : "xmark.shield.fill")
                        .foregroundStyle(valid ? .green : .red)
                    Text(valid
                        ? ProvikaStrings.Localizable.Gallery.Detail.Signature.valid
                        : ProvikaStrings.Localizable.Gallery.Detail.Signature.invalid
                    )
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(valid ? .green : .red)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 공유
            ShareLink(
                item: recording.fileURL,
                preview: SharePreview(recording.id, image: Image(systemName: "video"))
            ) {
                Label(ProvikaStrings.Localizable.Common.share, systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            // 신고 완료 표시
            if !recording.isReported {
                Button {
                    recording.isReported = true
                    recording.reportedAt = Date()
                } label: {
                    Label(
                        ProvikaStrings.Localizable.Gallery.Detail.markReported,
                        systemImage: "flag.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            } else {
                Label("Reported", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
            }

            // 삭제
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label(ProvikaStrings.Localizable.Common.delete, systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func loadContent() {
        let url = recording.fileURL
        if FileManager.default.fileExists(atPath: url.path) {
            player = AVPlayer(url: url)
        }
        loadMetadata()
        verifySignature()
    }

    private func loadMetadata() {
        let url = recording.sidecarURL
        guard let data = try? Data(contentsOf: url) else { return }
        metadata = try? JSONDecoder().decode(RecordingMetadata.self, from: data)
    }

    private func verifySignature() {
        guard let meta = metadata,
              let integrity = meta.integrity,
              let sigBase64 = integrity.signature,
              let sigData = Data(base64Encoded: sigBase64) else {
            return
        }

        let hashData = Data(integrity.hash.utf8)
        let service = SignatureService()
        signatureValid = try? service.verify(signature: sigData, data: hashData)
    }

    private func deleteRecording() {
        let vm = GalleryViewModel()
        vm.deleteRecording(recording, context: modelContext)
        dismiss()
    }
}
