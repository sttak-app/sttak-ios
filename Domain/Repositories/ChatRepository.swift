import Foundation

/// 챗봇(서버 LLM). 질문 → 진행 단계(stage) 0회 이상 → 완성 답변(answer) 1회.
/// 매핑: POST /chat (SSE, stage* → answer → source → done).
protocol ChatRepository: Sendable {
    /// 질문을 보내고 진행 단계·완성 답변을 스트리밍한다. (뉴스/구간 단발 질의)
    func ask(question: String, context: ChatContext) -> AsyncThrowingStream<ChatStreamEvent, Error>
    /// 멀티턴 대화: 직전까지의 히스토리를 보내고 다음 답변을 스트리밍한다.
    /// 히스토리는 클라이언트가 누적 전송(서버 무세션, 최근 10턴만 사용).
    func streamReply(history: [ChatMessage], context: ChatContext) -> AsyncThrowingStream<ChatStreamEvent, Error>
    /// 맥락별 빠른 선택 질문(추천). 매핑: GET /chat/suggestions?context=…
    func suggestedQuestions(for context: ChatContext) async throws -> [String]
}
