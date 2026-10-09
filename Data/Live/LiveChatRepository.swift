import Foundation

/// 챗봇 Live: POST /api/v1/chat (SSE) — stage*(진행 단계) → answer(완성 본문 1회) → source → done.
/// 오류는 `error`(message) → done 으로 끝나고 본문이 오지 않는다. keepalive(`:`)는 파서가 무시.
/// `event: source`(출처 목록)는 현재 UI가 소비하지 않아 무시한다.
struct LiveChatRepository: ChatRepository {
    let api: APIClient

    func ask(question: String, context: ChatContext) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        streamReply(
            history: [ChatMessage(role: .user, text: question, timestamp: Date())],
            context: context
        )
    }

    func streamReply(history: [ChatMessage], context: ChatContext) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        let api = self.api
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let body = try JSONCoding.encoder().encode(ChatRequestDTO(context: context, history: history))
                    let decoder = JSONCoding.decoder()
                    let events = api.serverSentEvents(.post("/api/v1/chat", body: body))
                    for try await event in events {
                        switch event.name {
                        case "stage":
                            if let data = event.data.data(using: .utf8),
                               let dto = try? decoder.decode(ChatStageEventDTO.self, from: data),
                               let stage = ChatStage(rawValue: dto.stage) {
                                continuation.yield(.stage(stage))
                            }
                            // 모르는 단계 값은 무시 — 서버가 단계를 추가해도 깨지지 않게.
                        case "answer":
                            if let data = event.data.data(using: .utf8),
                               let dto = try? decoder.decode(ChatAnswerEventDTO.self, from: data) {
                                continuation.yield(.answer(dto.text))
                            }
                        case "error":
                            // message는 사용자 노출 가능 문구(백엔드 계약) — 그대로 전달한다.
                            let message = event.data.data(using: .utf8)
                                .flatMap { try? decoder.decode(ChatErrorEventDTO.self, from: $0) }?
                                .message
                            throw RepositoryError.server(message: message)
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
