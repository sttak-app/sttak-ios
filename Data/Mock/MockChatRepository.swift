import Foundation

/// 챗봇 Mock. 빠른선택 질문은 해당 답변을, 그 외는 자유 답변을 글자 단위로 스트리밍한다.
struct MockChatRepository: ChatRepository {
    /// 글자 사이 지연(스트리밍 타이핑 UX 재현).
    var chunkDelay: Duration = .milliseconds(12)

    func ask(question: String, context: ChatContext) -> AsyncThrowingStream<String, Error> {
        let answer = MockData.quickAnswers.first { $0.question == question }?.answer ?? MockData.freeAnswer
        let delay = chunkDelay
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for character in answer {
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

    func suggestedQuestions(for context: ChatContext) async throws -> [String] {
        MockData.quickAnswers.map(\.question)
    }
}
