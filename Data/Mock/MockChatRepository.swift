import Foundation

/// 챗봇 Mock. 맥락별 빠른선택 답변/자유 답변을 글자 단위로 스트리밍한다. (SSE 준비)
struct MockChatRepository: ChatRepository {
    /// 글자 사이 지연(스트리밍 타이핑 UX 재현).
    var chunkDelay: Duration = .milliseconds(12)

    func ask(question: String, context: ChatContext) -> AsyncThrowingStream<String, Error> {
        stream(answer(for: question, context: context))
    }

    func streamReply(history: [ChatMessage], context: ChatContext) -> AsyncThrowingStream<String, Error> {
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

    private func stream(_ text: String) -> AsyncThrowingStream<String, Error> {
        let delay = chunkDelay
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for character in text {
                        try await Task.sleep(for: delay)
                        continuation.yield(String(character))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
