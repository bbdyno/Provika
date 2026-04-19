//
//  PreRecordBuffer.swift
//  Provika
//
//  Created by bbdyno on 4/16/26.
//

import AVFoundation
import os

final class PreRecordBuffer {
    struct VideoFrame {
        let time: CMTime
        let pixelBuffer: CVPixelBuffer
    }

    private var videoBuffers: [VideoFrame] = []
    private var audioBuffers: [CMSampleBuffer] = []
    private var bufferDuration: TimeInterval
    private let logger = Logger(subsystem: "com.bbdyno.app.provika", category: "PreRecord")

    var isEnabled: Bool { bufferDuration > 0 }
    var currentBufferSeconds: Int { Int(bufferDuration) }

    init(duration: TimeInterval = 0) {
        self.bufferDuration = duration
    }

    func updateDuration(_ duration: TimeInterval) {
        bufferDuration = duration
        if duration <= 0 {
            clear()
        }
    }

    func appendVideo(time: CMTime, renderedBuffer: CVPixelBuffer) {
        guard isEnabled else { return }
        videoBuffers.append(VideoFrame(time: time, pixelBuffer: renderedBuffer))
        trimToWindow()
    }

    func appendAudio(sampleBuffer: CMSampleBuffer) {
        guard isEnabled else { return }
        audioBuffers.append(sampleBuffer)
        trimAudioToWindow()
    }

    func flush() -> (video: [VideoFrame], audio: [CMSampleBuffer]) {
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
        guard let newest = videoBuffers.last else { return }
        let newestSeconds = CMTimeGetSeconds(newest.time)

        while let oldest = videoBuffers.first,
              newestSeconds - CMTimeGetSeconds(oldest.time) > bufferDuration {
            videoBuffers.removeFirst()
        }
    }

    private func trimAudioToWindow() {
        guard let videoStart = videoBuffers.first else {
            audioBuffers.removeAll()
            return
        }
        let videoStartTime = videoStart.time
        audioBuffers.removeAll { buffer in
            let time = CMSampleBufferGetPresentationTimeStamp(buffer)
            return CMTimeCompare(time, videoStartTime) < 0
        }
    }
}
