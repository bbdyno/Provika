import AVFoundation
import SwiftData
import SwiftUI
import UIKit

@Observable
final class GalleryViewModel {
    var selectedDate = Date()
    var recordingDates: Set<String> = []

    func loadRecordingDates(recordings: [Recording]) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        recordingDates = Set(recordings.map { formatter.string(from: $0.createdAt) })
    }

    func recordings(for date: Date, from allRecordings: [Recording]) -> [Recording] {
        let calendar = Calendar.current
        return allRecordings.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func generateThumbnail(for recording: Recording) async -> Data? {
        guard FileManager.default.fileExists(atPath: recording.fileURL.path) else { return nil }
        let asset = AVAsset(url: recording.fileURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 300, height: 300)

        do {
            let (cgImage, _) = try await generator.image(at: .zero)
            let uiImage = UIImage(cgImage: cgImage)
            return uiImage.jpegData(compressionQuality: 0.7)
        } catch {
            return nil
        }
    }

    func deleteRecording(_ recording: Recording, context: ModelContext) {
        FileStorage.deleteRecording(videoURL: recording.fileURL, sidecarURL: recording.sidecarURL)
        context.delete(recording)
    }

    func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
