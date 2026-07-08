import XCTest
@testable import sttak

/// 공통 응답 봉투 `{message, content}` 디코딩 — 성공/None-content/필수 content 누락.
final class EnvelopeDecodingTests: XCTestCase {

    private struct Payload: Decodable, Sendable, Equatable {
        let name: String
        let publishedAt: Date
    }

    func testDecode_successContent() throws {
        let json = Data("""
        {"message": null, "content": {"name": "sttak", "publishedAt": "2026-07-07T01:02:03Z"}}
        """.utf8)
        let envelope = try JSONCoding.decoder().decode(APIEnvelope<Payload>.self, from: json)
        let content = try envelope.requiredContent()
        XCTAssertEqual(content.name, "sttak")
        // ISO8601(소수점 없음) → epoch 손계산: 2026-07-07 01:02:03Z
        XCTAssertEqual(content.publishedAt.timeIntervalSince1970, 1_783_386_123, accuracy: 0.001)
    }

    func testDecode_fractionalSecondsDate() throws {
        let json = Data("""
        {"message": null, "content": {"name": "n", "publishedAt": "2026-07-07T01:02:03.500Z"}}
        """.utf8)
        let envelope = try JSONCoding.decoder().decode(APIEnvelope<Payload>.self, from: json)
        XCTAssertEqual(try envelope.requiredContent().publishedAt.timeIntervalSince1970, 1_783_386_123.5, accuracy: 0.001)
    }

    func testDecode_nullContent_isNil_andRequiredThrows() throws {
        let json = Data("""
        {"message": "아직 푼 퀴즈가 없어요", "content": null}
        """.utf8)
        let envelope = try JSONCoding.decoder().decode(APIEnvelope<Payload>.self, from: json)
        XCTAssertNil(envelope.content)
        XCTAssertEqual(envelope.message, "아직 푼 퀴즈가 없어요")
        XCTAssertThrowsError(try envelope.requiredContent()) { error in
            XCTAssertEqual(error as? RepositoryError, .decoding)
        }
    }
}
