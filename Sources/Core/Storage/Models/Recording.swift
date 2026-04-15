//
//  Recording.swift
//  Provika
//
//  Created by bbdyno on 4/16/26.
//

import Foundation
import SwiftData

@Model
final class Recording {
    @Attribute(.unique) var id: String
    var createdAt: Date
    var duration: TimeInterval
    var fileURLString: String
    var sidecarURLString: String
    var fileHash: String
    var startLatitude: Double?
    var startLongitude: Double?
    var endLatitude: Double?
    var endLongitude: Double?
    var userNote: String?
    var isReported: Bool
    var reportedAt: Date?
    var thumbnailData: Data?

    var fileURL: URL { URL(fileURLWithPath: fileURLString) }
    var sidecarURL: URL { URL(fileURLWithPath: sidecarURLString) }

    init(
        id: String,
        createdAt: Date,
        duration: TimeInterval,
        fileURL: URL,
        sidecarURL: URL,
        fileHash: String,
        startLatitude: Double? = nil,
        startLongitude: Double? = nil,
        endLatitude: Double? = nil,
        endLongitude: Double? = nil,
        userNote: String? = nil,
        isReported: Bool = false,
        reportedAt: Date? = nil,
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.duration = duration
        self.fileURLString = fileURL.path
        self.sidecarURLString = sidecarURL.path
        self.fileHash = fileHash
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
        self.userNote = userNote
        self.isReported = isReported
        self.reportedAt = reportedAt
        self.thumbnailData = thumbnailData
    }
}
