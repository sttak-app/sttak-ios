import SwiftUI

/// 공용 챗봇(멀티턴). 메시지 목록을 유지하고 히스토리를 보내 답변을 스트리밍한다.
/// 전송→스트리밍→누적→다음 턴. 취소(시트 닫힘)·에러·재진입은 커밋 12 패턴.
@MainActor
@Observable
final class ChatViewModel {
    enum StreamingState: Equatable {
        case idle, streaming, done, cancelled, error(String)
    }

    private(set) var messages: [ChatMessage] = []
    var input: String = ""
    private(set) var suggestions: [String] = []
    private(set) var streamingState: StreamingState = .idle

    private let chat: ChatRepository
    private let context: ChatContext
    private let greeting: String
    private var streamTask: Task<Void, Never>?

    init(chat: ChatRepository, context: ChatContext = .free, greeting: String) {
        self.chat = chat
        self.context = context
        self.greeting = greeting
    }

    var isStreaming: Bool { streamingState == .streaming }
    var errorMessage: String? { if case let .error(message) = streamingState { return message }; return nil }
    /// 빈 어시스턴트 말풍선(스트리밍 대기) 여부 — 타이핑 인디케이터 표시용.
    var isAwaitingFirstChunk: Bool {
        isStreaming && (messages.last.map { $0.role == .assistant && $0.text.isEmpty } ?? false)
    }

    /// 첫 진입 시 인사말 + 추천 질문 시드(1회).
    func start() async {
        guard messages.isEmpty else { return }
        messages = [ChatMessage(role: .assistant, text: greeting, timestamp: Date())]
        suggestions = (try? await chat.suggestedQuestions(for: context)) ?? []
    }

    func send(_ raw: String? = nil) {
        let text = (raw ?? input).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, streamingState != .streaming else { return }
        input = ""

        messages.append(ChatMessage(role: .user, text: text, timestamp: Date()))
        let history = messages                              // 사용자 발화까지 포함
        messages.append(ChatMessage(role: .assistant, text: "", timestamp: Date())) // 스트리밍 placeholder
        let assistantIndex = messages.count - 1
        streamingState = .streaming

        let stream = chat.streamReply(history: history, context: context)
        streamTask = Task { [weak self] in
            do {
                for try await chunk in stream {
                    if Task.isCancelled { break }
                    self?.appendChunk(chunk, at: assistantIndex)
                }
                self?.streamingState = Task.isCancelled ? .cancelled : .done
            } catch {
                self?.finishWithError(at: assistantIndex)
            }
        }
    }

    func retry() {
        guard case .error = streamingState,
              let lastUser = messages.last(where: { $0.role == .user })?.text else { return }
        // 직전 실패한 빈 어시스턴트 말풍선 제거 후 재시도.
        if messages.last?.role == .assistant, messages.last?.text.isEmpty == true { messages.removeLast() }
        if messages.last?.role == .user { messages.removeLast() }
        streamingState = .idle
        send(lastUser)
    }

    /// 시트 닫힘/턴 중단 — 진행 중 스트림 취소.
    func cancelStreaming() {
        streamTask?.cancel()
    }

    // MARK: 내부
    private func appendChunk(_ chunk: String, at index: Int) {
        guard messages.indices.contains(index) else { return }
        let existing = messages[index]
        messages[index] = ChatMessage(role: .assistant, text: existing.text + chunk, timestamp: existing.timestamp)
    }

    private func finishWithError(at index: Int) {
        if Task.isCancelled { streamingState = .cancelled; return }
        streamingState = .error("답변을 받지 못했어요. 잠시 후 다시 시도해 주세요.")
    }
}
