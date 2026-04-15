import XCTest
@testable import Provika

final class FileStorageTests: XCTestCase {

    func testRecordingsDirectoryCreation() {
        let url = FileStorage.recordingsDirectory
        XCTAssertTrue(url.path.contains("Recordings"))
    }

    func testDirectoryForDateCreatesFolder() {
        let date = Date()
        let dir = FileStorage.directoryForDate(date)

        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path))
        XCTAssertTrue(dir.lastPathComponent.contains("-"))
    }

    func testGenerateFileURLProducesCorrectExtension() {
        let date = Date()
        let movURL = FileStorage.generateFileURL(for: date, extension: "mov")
        let jsonURL = FileStorage.generateFileURL(for: date, extension: "json")

        XCTAssertEqual(movURL.pathExtension, "mov")
        XCTAssertEqual(jsonURL.pathExtension, "json")
    }

    func testGenerateFileURLIncrementsCounter() {
        let date = Date()
        let url1 = FileStorage.generateFileURL(for: date, extension: "mov")
        // 파일 생성하여 카운터 증가 유도
        FileManager.default.createFile(atPath: url1.path, contents: Data())

        let url2 = FileStorage.generateFileURL(for: date, extension: "mov")
        XCTAssertNotEqual(url1.lastPathComponent, url2.lastPathComponent)

        // 정리
        try? FileManager.default.removeItem(at: url1)
        try? FileManager.default.removeItem(at: url2)
    }
}
