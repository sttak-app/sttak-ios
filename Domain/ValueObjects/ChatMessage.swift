import Foundation

/// 챗봇 메시지 발화 주체.
enum ChatRole: Sendable, Equatable {
    case user
    case assistant
}

/// 챗봇 진입 맥락.
enum ChatContext: Sendable, Equatable {
    case news         // 뉴스 상세에서
    case chartSegment // 차트 구간에서
    case free         // 자유 질문
}

/// 챗봇 메시지 한 개. ChatSession의 구성 요소.
struct ChatMessage: Sendable, Equatable {
    let role: ChatRole
    let text: String
    let timestamp: Date
}
