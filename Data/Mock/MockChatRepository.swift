import Foundation

/// 챗봇 Mock. Live SSE 계약(stage* → answer)을 재현 — 진행 단계 두 번 뒤 완성본을 한 번에 준다.
struct MockChatRepository: ChatRepository {
    /// 이벤트 사이 지연(진행 단계 UX 재현). 테스트는 0으로 결정적.
    var eventDelay: Duration = .milliseconds(350)

    func ask(question: String, context: ChatContext) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        stream(answer(for: question, context: context))
    }

    func streamReply(history: [ChatMessage], context: ChatContext) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        // 멀티턴: 마지막 사용자 발화에 답한다. (Mock은 히스토리를 분석하지 않음 — Live LLM이 활용)
        let question = history.last { $0.role == .user }?.text ?? ""
        return stream(answer(for: question, context: context))
    }

    func suggestedQuestions(for context: ChatContext) async throws -> [String] {
        pairs(for: context).map(\.question)
    }

    // MARK: 내부
    private func pairs(for context: ChatContext) -> [(question: String, answer: String)] {
        context == .free ? MockData.freeQuickAnswers : MockData.quickAnswers
    }

    private func answer(for question: String, context: ChatContext) -> String {
        if let match = pairs(for: context).first(where: { $0.question == question }) { return match.answer }
        return context == .free ? MockData.freeChatFallback : MockData.freeAnswer
    }

    private func stream(_ text: String) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        let delay = eventDelay
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(.stage(.generating))
                    try await Task.sleep(for: delay)
                    continuation.yield(.stage(.verifying))
                    try await Task.sleep(for: delay)
                    continuation.yield(.answer(text))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
