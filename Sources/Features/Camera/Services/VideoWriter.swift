//
//  VideoWriter.swift
//  Provika
//
//  Created by bbdyno on 4/16/26.
//

import AVFoundation
import os

final class VideoWriter {
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private(set) var isWriting = false
    private(set) var outputURL: URL?
    private var startTime: CMTime?
    private let logger = Logger(subsystem: "com.bbdyno.app.provika", category: "VideoWriter")

    func startWriting(
        to url: URL,
        width: Int,
        height: Int,
        codec: AVVideoCodecType = .hevc,
        audioSettings: [String: Any]? = nil
    ) throws {
        outputURL = url
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)

        // 비디오 입력
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: width * height * 6
            ]
        ]

        let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        vInput.expectsMediaDataInRealTime = true

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: vInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )

        if writer.canAdd(vInput) {
            writer.add(vInput)
        }

        videoInput = vInput
        pixelBufferAdaptor = adaptor

        // 오디오 입력
        let aSettings = audioSettings ?? [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 128000
        ]

        let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: aSettings)
        aInput.expectsMediaDataInRealTime = true

        if writer.canAdd(aInput) {
            writer.add(aInput)
        }

        audioInput = aInput
        assetWriter = writer
        startTime = nil
        isWriting = true
        logger.info("비디오 작성 시작: \(url.lastPathComponent)")
    }

    func appendVideoBuffer(_ pixelBuffer: CVPixelBuffer, at presentationTime: CMTime) {
        guard isWriting, let writer = assetWriter, let adaptor = pixelBufferAdaptor else { return }

        if startTime == nil {
            startTime = presentationTime
            writer.startWriting()
            writer.startSession(atSourceTime: presentationTime)
        }

        guard let videoInput, videoInput.isReadyForMoreMediaData else { return }
        adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
    }

    func appendAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isWriting, startTime != nil else { return }
        guard let audioInput, audioInput.isReadyForMoreMediaData else { return }
        audioInput.append(sampleBuffer)
    }

    func finishWriting() async -> URL? {
        guard isWriting, let writer = assetWriter else { return nil }
        isWriting = false
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        await writer.finishWriting()

        if writer.status == .completed {
            logger.info("비디오 작성 완료: \(writer.outputURL.lastPathComponent)")
            return writer.outputURL
        } else {
            logger.error("비디오 작성 실패: \(String(describing: writer.error))")
            return nil
        }
    }
}
