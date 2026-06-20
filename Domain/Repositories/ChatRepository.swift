import Foundation

/// 챗봇(서버 LLM 스트리밍). 질문 → 점진적 텍스트 조각.
/// 매핑: POST /chat (SSE). 스트림으로 두어 나중 SSE 교체가 매끄럽다.
protocol ChatRepository: Sendable {
    /// 질문을 보내고 답변을 조각(텍스트)으로 스트리밍한다.
    func ask(question: String, context: ChatContext) -> AsyncThrowingStream<String, Error>
}
