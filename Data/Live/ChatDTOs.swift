import Foundation

/// POST /api/v1/chat 요청 바디. 컨텍스트·역할은 SCREAMING_SNAKE_CASE.
struct ChatRequestDTO: Encodable, Sendable {
    struct Message: Encodable, Sendable {
        let role: String        // "USER" | "ASSISTANT"
        let text: String
        let timestamp: Date
    }

    let context: String         // "NEWS" | "CHART_SEGMENT" | "FREE"
    let history: [Message]

    init(context: ChatContext, history: [ChatMessage]) {
        self.context = context.apiValue
        self.history = history.map { message in
            Message(
                role: message.role == .user ? "USER" : "ASSISTANT",
                text: message.text,
                timestamp: message.timestamp
            )
        }
    }
}

/// GET /api/v1/chat/suggestions 응답.
struct ChatSuggestionsDTO: Decodable, Sendable {
    let questions: [String]
}

/// SSE `event: token` 페이로드.
struct ChatTokenEventDTO: Decodable, Sendable {
    let text: String
}

extension ChatContext {
    var apiValue: String {
        switch self {
        case .news: return "NEWS"
        case .chartSegment: return "CHART_SEGMENT"
        case .free: return "FREE"
        }
    }
}
