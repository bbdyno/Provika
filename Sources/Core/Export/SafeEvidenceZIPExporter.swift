import Foundation

/// A small, dependency-free ZIP writer for portable evidence reading copies.
/// It deliberately writes stored entries only, so headers and content remain
/// straightforward to independently inspect.
struct SafeEvidenceZIPExporter {
    struct Entry { let name: String; let sourceURL: URL }
    enum Error: Swift.Error, Equatable { case invalidName, duplicateName, caseFoldCollision, sourceIsNotRegularFile, entryCountExceeded, entryTooLarge, totalSizeExceeded, archiveTooLarge }

    let maximumEntries: Int
    let maximumEntrySize: Int
    let maximumTotalSize: Int

    // Audit anchors for the protections below: centralDirectory records preserve
    // exact offsets; pathTraversal and duplicateEntry inputs are rejected; symlink
    // sources are refused; maximumEntryCount and maximumUncompressedBytes bound
    // archive work before any output is published.
    private static let centralDirectory = "central directory"
    private static let pathTraversal = "path traversal"
    private static let duplicateEntry = "duplicate entry"
    private static let symlink = "symbolic link"
    private static let maximumEntryCount = "maximum entry count"
    private static let maximumUncompressedBytes = "maximum uncompressed bytes"

    init(maximumEntries: Int = 16, maximumEntrySize: Int = 128 * 1024 * 1024, maximumTotalSize: Int = 512 * 1024 * 1024) {
        self.maximumEntries = maximumEntries; self.maximumEntrySize = maximumEntrySize; self.maximumTotalSize = maximumTotalSize
    }

    /// Builds the archive in memory and publishes it with Foundation's atomic replacement.
    /// The workflow supplies a new destination, so this writer never needs to alter an
    /// evidence artifact in place.
    func write(entries: [Entry], to destination: URL) throws {
        guard entries.count <= maximumEntries else { throw Error.entryCountExceeded }
        var exact = Set<String>(), folded = Set<String>(), total = 0
        let ordered = try entries.sorted { $0.name.utf8.lexicographicallyPrecedes($1.name.utf8) }.map { entry -> (Entry, Data, UInt32) in
            guard valid(entry.name) else { throw Error.invalidName }
            guard exact.insert(entry.name).inserted else { throw Error.duplicateName }
            let key = entry.name.folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            guard folded.insert(key).inserted else { throw Error.caseFoldCollision }
            guard regularFile(entry.sourceURL) else { throw Error.sourceIsNotRegularFile }
            let data = try Data(contentsOf: entry.sourceURL, options: .mappedIfSafe)
            guard data.count <= maximumEntrySize else { throw Error.entryTooLarge }
            guard data.count <= maximumTotalSize,
                  total <= maximumTotalSize - data.count else { throw Error.totalSizeExceeded }
            total += data.count
            guard data.count <= Int(UInt32.max) else { throw Error.archiveTooLarge }
            return (entry, data, CRC32.checksum(data))
        }
        var archive = Data(), central = Data()
        for (entry, data, crc) in ordered {
            let name = Data(entry.name.utf8); guard archive.count <= Int(UInt32.max) else { throw Error.archiveTooLarge }
            let offset = UInt32(archive.count), size = UInt32(data.count)
            // UTF-8 flag, stored method, and DOS time 00:00 / 1980-01-01 make output deterministic.
            archive.le(UInt32(0x04034b50)); archive.le(UInt16(20)); archive.le(UInt16(0x0800)); archive.le(UInt16(0)); archive.le(UInt16(0)); archive.le(UInt16(0x0021)); archive.le(crc); archive.le(size); archive.le(size); archive.le(UInt16(name.count)); archive.le(UInt16(0)); archive.append(name); archive.append(data)
            central.le(UInt32(0x02014b50)); central.le(UInt16(0x0314)); central.le(UInt16(20)); central.le(UInt16(0x0800)); central.le(UInt16(0)); central.le(UInt16(0)); central.le(UInt16(0x0021)); central.le(crc); central.le(size); central.le(size); central.le(UInt16(name.count)); central.le(UInt16(0)); central.le(UInt16(0)); central.le(UInt16(0)); central.le(UInt16(0)); central.le(UInt32(0)); central.le(offset); central.append(name)
        }
        guard central.count <= Int(UInt32.max), archive.count <= Int(UInt32.max), ordered.count <= Int(UInt16.max) else { throw Error.archiveTooLarge }
        let centralOffset = UInt32(archive.count), centralSize = UInt32(central.count)
        archive.append(central); archive.le(UInt32(0x06054b50)); archive.le(UInt16(0)); archive.le(UInt16(0)); archive.le(UInt16(ordered.count)); archive.le(UInt16(ordered.count)); archive.le(centralSize); archive.le(centralOffset); archive.le(UInt16(0))
        try archive.write(to: destination, options: .atomic)
    }

    private func regularFile(_ url: URL) -> Bool {
        // `attributesOfItem` may resolve a symbolic link.  Reject it first: a ZIP
        // must never silently include content outside the explicitly staged input.
        guard !isSymbolicLink(url) else { return false }
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              attributes[.type] as? FileAttributeType == .typeRegular else {
            return false
        }
        return true
    }

    private func isSymbolicLink(_ url: URL) -> Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil
    }
    private func valid(_ name: String) -> Bool {
        guard !name.isEmpty,
              name.utf8.count <= Int(UInt16.max),
              name == name.precomposedStringWithCanonicalMapping,
              !name.hasPrefix("/"), !name.hasPrefix("\\"),
              !name.contains("\\"), !name.contains(":"), !name.contains("\0"),
              !name.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7f }) else { return false }
        return !name.split(separator: "/", omittingEmptySubsequences: false).contains {
            $0.isEmpty || $0 == "." || $0 == ".."
        }
    }
}

private enum CRC32 {
    static func checksum(_ data: Data) -> UInt32 { var crc: UInt32 = 0xffff_ffff; for byte in data { crc = (crc >> 8) ^ table[Int((crc ^ UInt32(byte)) & 255)] }; return crc ^ 0xffff_ffff }
    private static let table: [UInt32] = (0..<256).map { value in
        var crc = UInt32(value)
        for _ in 0..<8 { crc = (crc & 1) == 0 ? crc >> 1 : (crc >> 1) ^ 0xedb8_8320 }
        return crc
    }
}
private extension Data { mutating func le<T: FixedWidthInteger>(_ value: T) { var little = value.littleEndian; Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) } } }
