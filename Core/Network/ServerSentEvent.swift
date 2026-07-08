import Foundation

/// SSE 이벤트 한 건. name은 `event:` 줄(없으면 "message"), data는 `data:` 줄의 페이로드.
struct ServerSentEvent: Sendable, Equatable {
    let name: String
    let data: String
}

/// SSE 줄 단위 파서.
/// 백엔드는 `event: <name>` 다음 `data: <json>` 한 줄씩 보낸다.
/// `AsyncLineSequence`가 빈 줄을 건너뛸 수 있어(디스패치 경계로 빈 줄에 의존 금지),
/// `data:` 줄을 받는 즉시 직전 `event:` 이름으로 이벤트를 확정한다.
struct SSELineParser: Sendable {
    private var currentEventName = "message"

    /// 한 줄을 소비하고, 이벤트가 완성되면 반환한다.
    mutating func consume(line: String) -> ServerSentEvent? {
        if line.isEmpty {
            // 이벤트 경계 — 다음 이벤트는 기본 이름으로 리셋.
            currentEventName = "message"
            return nil
        }
        if line.hasPrefix(":") {
            return nil // 주석/keep-alive
        }
        if let value = fieldValue(of: "event", in: line) {
            currentEventName = value
            return nil
        }
        if let value = fieldValue(of: "data", in: line) {
            return ServerSentEvent(name: currentEventName, data: value)
        }
        return nil // id:, retry: 등은 무시
    }

    /// `field: value` 형태에서 value 추출(콜론 뒤 선행 공백 1개 제거 — SSE 스펙).
    private func fieldValue(of field: String, in line: String) -> String? {
        guard line.hasPrefix("\(field):") else {
            return line == field ? "" : nil
        }
        var value = line.dropFirst(field.count + 1)
        if value.hasPrefix(" ") { value = value.dropFirst() }
        return String(value)
    }
}
