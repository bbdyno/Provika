import XCTest
@testable import Provika

final class HashCalculatorTests: XCTestCase {

    func testSHA256ProducesSameHashForSameContent() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let file1 = tempDir.appendingPathComponent("test_hash_1.txt")
        let file2 = tempDir.appendingPathComponent("test_hash_2.txt")

        let content = "Provika test content for hash verification"
        try content.write(to: file1, atomically: true, encoding: .utf8)
        try content.write(to: file2, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: file1)
            try? FileManager.default.removeItem(at: file2)
        }

        let hash1 = try HashCalculator.sha256(of: file1)
        let hash2 = try HashCalculator.sha256(of: file2)

        XCTAssertEqual(hash1, hash2, "동일 콘텐츠의 해시가 같아야 함")
        XCTAssertEqual(hash1.count, 64, "SHA-256 해시는 64자 hex 문자열이어야 함")
    }

    func testSHA256ProducesDifferentHashForDifferentContent() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let file1 = tempDir.appendingPathComponent("test_hash_diff_1.txt")
        let file2 = tempDir.appendingPathComponent("test_hash_diff_2.txt")

        try "original content".write(to: file1, atomically: true, encoding: .utf8)
        try "modified content".write(to: file2, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: file1)
            try? FileManager.default.removeItem(at: file2)
        }

        let hash1 = try HashCalculator.sha256(of: file1)
        let hash2 = try HashCalculator.sha256(of: file2)

        XCTAssertNotEqual(hash1, hash2, "다른 콘텐츠의 해시가 달라야 함")
    }

    func testSHA256OneByteDifferenceProducesDifferentHash() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let file1 = tempDir.appendingPathComponent("test_hash_byte_1.txt")
        let file2 = tempDir.appendingPathComponent("test_hash_byte_2.txt")

        try Data([0x41, 0x42, 0x43]).write(to: file1)
        try Data([0x41, 0x42, 0x44]).write(to: file2) // 1바이트 변경

        defer {
            try? FileManager.default.removeItem(at: file1)
            try? FileManager.default.removeItem(at: file2)
        }

        let hash1 = try HashCalculator.sha256(of: file1)
        let hash2 = try HashCalculator.sha256(of: file2)

        XCTAssertNotEqual(hash1, hash2, "1바이트 변경 시 해시가 달라야 함")
    }

    func testSHA256DataHash() {
        let data1 = Data("test data".utf8)
        let data2 = Data("test data".utf8)
        let data3 = Data("different data".utf8)

        XCTAssertEqual(
            HashCalculator.sha256(of: data1),
            HashCalculator.sha256(of: data2)
        )
        XCTAssertNotEqual(
            HashCalculator.sha256(of: data1),
            HashCalculator.sha256(of: data3)
        )
    }
}
