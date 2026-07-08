import Foundation

/// 챗봇 대화 세션. 진입 맥락(뉴스/구간/자유)과 메시지 목록을 보유한다.
struct ChatSession: Sendable, Equatable, Identifiable {
    let id: String
    let context: ChatContext
    let messages: [ChatMessage]
}
