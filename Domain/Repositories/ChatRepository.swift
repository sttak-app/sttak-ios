import Foundation

/// 챗봇(서버 LLM 스트리밍). 질문 → 점진적 텍스트 조각.
/// 매핑: POST /chat (SSE). 스트림으로 두어 나중 SSE 교체가 매끄럽다.
protocol ChatRepository: Sendable {
    /// 질문을 보내고 답변을 조각(텍스트)으로 스트리밍한다. (뉴스/구간 단발 질의)
    func ask(question: String, context: ChatContext) -> AsyncThrowingStream<String, Error>
    /// 멀티턴 대화: 직전까지의 히스토리를 보내고 다음 답변을 조각으로 스트리밍한다.
    /// 매핑: POST /chat (SSE, messages 배열 전달).
    func streamReply(history: [ChatMessage], context: ChatContext) -> AsyncThrowingStream<String, Error>
    /// 맥락별 빠른 선택 질문(추천). 매핑: GET /chat/suggestions?context=…
    func suggestedQuestions(for context: ChatContext) async throws -> [String]
}
