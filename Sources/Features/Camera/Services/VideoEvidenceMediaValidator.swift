import AVFoundation
import Foundation

struct VideoEvidenceMediaObservation: Equatable, Sendable {
    let videoTrack: VideoEvidenceClaimV2.Track
    let audioTrack: VideoEvidenceClaimV2.Track?
    let playable: Bool
}

enum VideoEvidenceMediaValidationError: Error, Equatable {
    case unreadable
    case notPlayable
    case missingVideoTrack
    case missingRequiredAudioTrack
    case unexpectedAudioTrack
}

/// Read-only AVFoundation inspection after the writer finalization callback.
struct VideoEvidenceMediaValidator {
    func validate(
        url: URL,
        audioObservation: VideoAudioPermissionObservation
    ) -> Result<VideoEvidenceMediaObservation, VideoEvidenceMediaValidationError> {
        guard FileManager.default.isReadableFile(atPath: url.path) else { return .failure(.unreadable) }
        let asset = AVURLAsset(url: url)
        guard asset.isPlayable else { return .failure(.notPlayable) }
        guard let video = asset.tracks(withMediaType: .video).first else { return .failure(.missingVideoTrack) }
        let audio = asset.tracks(withMediaType: .audio).first
        if audioObservation.audioIncluded, audio == nil { return .failure(.missingRequiredAudioTrack) }
        if !audioObservation.audioIncluded, audio != nil { return .failure(.unexpectedAudioTrack) }

        return .success(.init(
            videoTrack: .init(
                kind: "video",
                codec: codecName(video),
                durationMilliseconds: milliseconds(video.timeRange.duration),
                width: Int(abs(video.naturalSize.width.rounded())),
                height: Int(abs(video.naturalSize.height.rounded())),
                channelCount: nil
            ),
            audioTrack: audio.map {
                .init(
                    kind: "audio",
                    codec: codecName($0),
                    durationMilliseconds: milliseconds($0.timeRange.duration),
                    width: nil,
                    height: nil,
                    channelCount: channelCount($0)
                )
            },
            playable: true
        ))
    }

    private func milliseconds(_ time: CMTime) -> Int64 {
        let seconds = CMTimeGetSeconds(time)
        guard seconds.isFinite, seconds >= 0 else { return 0 }
        return Int64((seconds * 1_000).rounded())
    }

    private func codecName(_ track: AVAssetTrack) -> String {
        guard let description = track.formatDescriptions.first else { return "unknown" }
        let code = CMFormatDescriptionGetMediaSubType(description as! CMFormatDescription)
        let bytes: [UInt8] = [UInt8((code >> 24) & 0xff), UInt8((code >> 16) & 0xff), UInt8((code >> 8) & 0xff), UInt8(code & 0xff)]
        return String(bytes: bytes, encoding: .ascii) ?? String(code)
    }

    private func channelCount(_ track: AVAssetTrack) -> Int? {
        guard let description = track.formatDescriptions.first,
              let stream = CMAudioFormatDescriptionGetStreamBasicDescription(description as! CMAudioFormatDescription) else { return nil }
        return Int(stream.pointee.mChannelsPerFrame)
    }
}
