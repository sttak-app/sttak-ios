import Foundation

/// 챗봇 Live: POST /api/v1/chat (SSE) → token 조각 스트리밍, 추천 질문은 GET /chat/suggestions.
/// `event: source`(출처 목록)는 현재 UI가 소비하지 않아 무시한다.
struct LiveChatRepository: ChatRepository {
    let api: APIClient

    func ask(question: String, context: ChatContext) -> AsyncThrowingStream<String, Error> {
        streamReply(
            history: [ChatMessage(role: .user, text: question, timestamp: Date())],
            context: context
        )
    }

    func streamReply(history: [ChatMessage], context: ChatContext) -> AsyncThrowingStream<String, Error> {
        let api = self.api
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let body = try JSONCoding.encoder().encode(ChatRequestDTO(context: context, history: history))
                    let decoder = JSONCoding.decoder()
                    let events = api.serverSentEvents(.post("/api/v1/chat", body: body))
                    for try await event in events {
                        switch event.name {
                        case "token":
                            if let data = event.data.data(using: .utf8),
                               let token = try? decoder.decode(ChatTokenEventDTO.self, from: data) {
                                continuation.yield(token.text)
                            }
                        case "error":
                            // 서버가 스트림 도중 실패를 알림(이후 done이 오지만 여기서 종료).
                            throw RepositoryError.server(message: nil)
                        case "done":
                            continuation.finish()
                            return
                        default:
                            break // source 등은 현재 미사용
                        }
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
        let dto: ChatSuggestionsDTO = try await api.request(
            .get("/api/v1/chat/suggestions", query: [URLQueryItem(name: "context", value: context.apiValue)])
        )
        return dto.questions
    }
}
