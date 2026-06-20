import SwiftUI

/// 뉴스 상세 시트 상태. 쉬운풀이/원문/AI 3탭 + AI 스트리밍 상태머신(누적·완료·취소·에러).
@MainActor
@Observable
final class NewsDetailViewModel {
    enum Tab: Int, CaseIterable {
        case easy, origin, ai
    }

    enum StreamingState: Equatable {
        case idle
        case streaming
        case done
        case cancelled
        case error(String)
    }

    struct ChatTurn: Identifiable, Equatable {
        let id: Int
        let role: ChatRole
        var text: String
    }

    let news: NewsItem
    let stockName: String

    var selectedTab: Tab = .easy {
        didSet {
            // AI 탭을 떠나면 진행 중 스트리밍 취소.
            if oldValue == .ai && selectedTab != .ai { cancelStreaming() }
        }
    }
    private(set) var openTerms: Set<Int> = []

    // AI
    private(set) var messages: [ChatTurn] = []
    private(set) var streamingState: StreamingState = .idle
    private(set) var suggestedQuestions: [String] = []
    var chatInput: String = ""

    private let chat: ChatRepository
    private var streamTask: Task<Void, Never>?
    private var turnCounter = 0

    init(news: NewsItem, stockName: String, chat: ChatRepository) {
        self.news = news
        self.stockName = stockName
        self.chat = chat
    }

    var isStreaming: Bool { streamingState == .streaming }

    func toggleTerm(_ index: Int) {
        if openTerms.contains(index) { openTerms.remove(index) } else { openTerms.insert(index) }
    }

    func loadSuggestions() async {
        suggestedQuestions = (try? await chat.suggestedQuestions(for: .news)) ?? []
    }

    /// 질문 전송 → 스트리밍 소비. 진행 중이면 무시(중복 방지).
    func ask(_ question: String) {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, streamingState != .streaming else { return }

        appendTurn(role: .user, text: trimmed)
        let assistantIndex = appendTurn(role: .assistant, text: "")
        streamingState = .streaming

        let stream = chat.ask(question: trimmed, context: .news)
        streamTask = Task { [weak self] in
            do {
                for try await chunk in stream {
                    if Task.isCancelled { break }
                    self?.append(chunk, at: assistantIndex)
                }
                self?.streamingState = Task.isCancelled ? .cancelled : .done
            } catch {
                self?.streamingState = Task.isCancelled
                    ? .cancelled
                    : .error("답변을 받지 못했어요. 잠시 후 다시 시도해 주세요.")
            }
        }
    }

    func sendFree() {
        let text = chatInput
        chatInput = ""
        ask(text)
    }

    /// 에러 후 재시도 — 실패한 마지막 질문을 깨끗이 다시 묻는다.
    func retry() {
        guard let lastUser = messages.last(where: { $0.role == .user })?.text else { return }
        if messages.last?.role == .assistant { messages.removeLast() }
        if messages.last?.role == .user { messages.removeLast() }
        streamingState = .idle
        ask(lastUser)
    }

    /// 진행 중 스트리밍 취소(시트 닫힘·탭 전환·뷰 사라짐 시).
    func cancelStreaming() {
        streamTask?.cancel()
    }

    // MARK: 내부
    @discardableResult
    private func appendTurn(role: ChatRole, text: String) -> Int {
        turnCounter += 1
        messages.append(ChatTurn(id: turnCounter, role: role, text: text))
        return messages.count - 1
    }

    private func append(_ chunk: String, at index: Int) {
        guard index < messages.count else { return }
        messages[index].text += chunk
    }
}
