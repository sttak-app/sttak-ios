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
    /// 챗봇이 "어떤 종목의 뉴스인지"를 서버에 알리기 위한 코드.
    private let stockCode: String

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
    /// 서버가 보낸 마지막 진행 단계 — 스트리밍 중 대기 문구로 표시한다.
    private(set) var stage: ChatStage?
    private(set) var suggestedQuestions: [String] = []
    var chatInput: String = ""

    private let chat: ChatRepository
    private var streamTask: Task<Void, Never>?
    private var turnCounter = 0

    init(news: NewsItem, stockName: String, stockCode: String, chat: ChatRepository) {
        self.news = news
        self.stockName = stockName
        self.stockCode = stockCode
        self.chat = chat
    }

    var isStreaming: Bool { streamingState == .streaming }

    /// 챗봇에 넘기는 맥락. newsId는 피드 응답에 id가 생기면 자동으로 채워진다(NewsItemDTO.id).
    private var chatContext: ChatContext {
        .news(stockCode: stockCode, newsId: news.newsId)
    }

    func toggleTerm(_ index: Int) {
        if openTerms.contains(index) { openTerms.remove(index) } else { openTerms.insert(index) }
    }

    func loadSuggestions() async {
        suggestedQuestions = (try? await chat.suggestedQuestions(for: chatContext)) ?? []
    }

    /// 질문 전송 → 스트리밍 소비. 진행 중이면 무시(중복 방지).
    func ask(_ question: String) {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, streamingState != .streaming else { return }

        appendTurn(role: .user, text: trimmed)
        let assistantIndex = appendTurn(role: .assistant, text: "")
        streamingState = .streaming
        stage = nil

        let stream = chat.ask(question: trimmed, context: chatContext)
        streamTask = Task { [weak self] in
            do {
                for try await event in stream {
                    if Task.isCancelled { break }
                    switch event {
                    case .stage(let stage):
                        self?.stage = stage
                    case .answer(let answer):
                        self?.setAnswer(answer, at: assistantIndex)
                    }
                }
                self?.stage = nil
                self?.streamingState = Task.isCancelled ? .cancelled : .done
            } catch {
                self?.stage = nil
                self?.finishWithError(error)
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

    private func setAnswer(_ text: String, at index: Int) {
        guard index < messages.count else { return }
        messages[index].text = text
    }

    private func finishWithError(_ error: Error) {
        if Task.isCancelled { streamingState = .cancelled; return }
        // 서버 error 이벤트의 message는 사용자 노출 가능 문구(백엔드 계약) — 그대로 보여준다.
        if let repoError = error as? RepositoryError, case let .server(message?) = repoError {
            streamingState = .error(message)
        } else {
            streamingState = .error("답변을 받지 못했어요. 잠시 후 다시 시도해 주세요.")
        }
    }
}
