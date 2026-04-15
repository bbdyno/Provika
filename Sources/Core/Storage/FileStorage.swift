import Foundation
import os

enum FileStorage {
    private static let logger = Logger(subsystem: "com.bbdyno.app.provika", category: "FileStorage")

    static var recordingsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Recordings", isDirectory: true)
    }

    static func directoryForDate(_ date: Date) -> URL {
        let dir = recordingsDirectory.appendingPathComponent(date.folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func generateFileURL(for date: Date, extension ext: String) -> URL {
        let dir = directoryForDate(date)
        let counter = nextCounter(in: dir, prefix: date.fileNamePrefix)
        let fileName = "\(date.fileNamePrefix)_\(String(format: "%03d", counter)).\(ext)"
        return dir.appendingPathComponent(fileName)
    }

    static func totalStorageUsed() -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: recordingsDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let size = values.fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    static func deleteRecording(videoURL: URL, sidecarURL: URL) {
        try? FileManager.default.removeItem(at: videoURL)
        try? FileManager.default.removeItem(at: sidecarURL)
        logger.info("녹화 파일 삭제: \(videoURL.lastPathComponent)")
    }

    private static func nextCounter(in directory: URL, prefix: String) -> Int {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return 1 }

        let existing = contents
            .map(\.lastPathComponent)
            .filter { $0.hasPrefix(prefix) }
            .compactMap { name -> Int? in
                let parts = name.split(separator: "_")
                guard parts.count >= 3 else { return nil }
                let counterPart = parts[2].split(separator: ".").first ?? ""
                return Int(counterPart)
            }

        return (existing.max() ?? 0) + 1
    }
}
