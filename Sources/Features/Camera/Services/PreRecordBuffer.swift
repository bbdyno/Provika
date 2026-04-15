import AVFoundation
import os

final class PreRecordBuffer {
    private var videoBuffers: [(CMSampleBuffer, CVPixelBuffer)] = []
    private var audioBuffers: [CMSampleBuffer] = []
    private var bufferDuration: TimeInterval
    private let logger = Logger(subsystem: "com.bbdyno.app.provika", category: "PreRecord")

    var isEnabled: Bool { bufferDuration > 0 }
    var currentBufferSeconds: Int { Int(bufferDuration) }

    init(duration: TimeInterval = 15.0) {
        self.bufferDuration = duration
    }

    func updateDuration(_ duration: TimeInterval) {
        bufferDuration = duration
        if duration <= 0 {
            clear()
        }
    }

    func appendVideo(sampleBuffer: CMSampleBuffer, renderedBuffer: CVPixelBuffer) {
        guard isEnabled else { return }
        videoBuffers.append((sampleBuffer, renderedBuffer))
        trimToWindow()
    }

    func appendAudio(sampleBuffer: CMSampleBuffer) {
        guard isEnabled else { return }
        audioBuffers.append(sampleBuffer)
        trimAudioToWindow()
    }

    func flush() -> (video: [(CMSampleBuffer, CVPixelBuffer)], audio: [CMSampleBuffer]) {
        let video = videoBuffers
        let audio = audioBuffers
        videoBuffers.removeAll()
        audioBuffers.removeAll()
        logger.info("선녹화 버퍼 플러시: 비디오 \(video.count)프레임, 오디오 \(audio.count)프레임")
        return (video, audio)
    }

    func clear() {
        videoBuffers.removeAll()
        audioBuffers.removeAll()
    }

    private func trimToWindow() {
        guard let oldest = videoBuffers.first,
              let newest = videoBuffers.last else { return }

        let oldestTime = CMSampleBufferGetPresentationTimeStamp(oldest.0)
        let newestTime = CMSampleBufferGetPresentationTimeStamp(newest.0)
        let elapsed = CMTimeGetSeconds(newestTime) - CMTimeGetSeconds(oldestTime)

        while elapsed > bufferDuration && videoBuffers.count > 1 {
            videoBuffers.removeFirst()
            guard let first = videoBuffers.first else { break }
            let firstTime = CMSampleBufferGetPresentationTimeStamp(first.0)
            let currentElapsed = CMTimeGetSeconds(newestTime) - CMTimeGetSeconds(firstTime)
            if currentElapsed <= bufferDuration { break }
        }
    }

    private func trimAudioToWindow() {
        guard let videoStart = videoBuffers.first else {
            audioBuffers.removeAll()
            return
        }
        let videoStartTime = CMSampleBufferGetPresentationTimeStamp(videoStart.0)

        audioBuffers.removeAll { buffer in
            let time = CMSampleBufferGetPresentationTimeStamp(buffer)
            return CMTimeCompare(time, videoStartTime) < 0
        }
    }
}
