import XCTest
@testable import sttak

/// SSE 줄 파서 — event/data 짝, 빈 줄 생략(AsyncLineSequence 특성), 주석, 기본 이벤트 이름.
final class SSELineParserTests: XCTestCase {

    private func parse(_ lines: [String]) -> [ServerSentEvent] {
        var parser = SSELineParser()
        return lines.compactMap { parser.consume(line: $0) }
    }

    func testTokenStream_withBlankLineDelimiters() {
        let events = parse([
            "event: token",
            "data: {\"text\":\"안\"}",
            "",
            "event: token",
            "data: {\"text\":\"녕\"}",
            "",
            "event: done",
            "data: {}",
            "",
        ])
        XCTAssertEqual(events, [
            ServerSentEvent(name: "token", data: "{\"text\":\"안\"}"),
            ServerSentEvent(name: "token", data: "{\"text\":\"녕\"}"),
            ServerSentEvent(name: "done", data: "{}"),
        ])
    }

    /// URLSession의 lines가 빈 줄을 건너뛰어도 동일하게 파싱되어야 한다(빈 줄 의존 금지).
    func testTokenStream_withoutBlankLines() {
        let events = parse([
            "event: token",
            "data: {\"text\":\"a\"}",
            "event: source",
            "data: {\"sources\":[]}",
            "event: done",
            "data: {}",
        ])
        XCTAssertEqual(events.map(\.name), ["token", "source", "done"])
        XCTAssertEqual(events[0].data, "{\"text\":\"a\"}")
    }

    func testDefaultEventName_isMessage() {
        let events = parse(["data: hello"])
        XCTAssertEqual(events, [ServerSentEvent(name: "message", data: "hello")])
    }

    func testCommentAndUnknownFields_areIgnored() {
        let events = parse([
            ": keep-alive",
            "id: 42",
            "retry: 3000",
            "event: token",
            "data: x",
        ])
        XCTAssertEqual(events, [ServerSentEvent(name: "token", data: "x")])
    }

    func testDataWithoutLeadingSpace_isParsed() {
        let events = parse(["event:token", "data:{\"text\":\"y\"}"])
        XCTAssertEqual(events, [ServerSentEvent(name: "token", data: "{\"text\":\"y\"}")])
    }
}
