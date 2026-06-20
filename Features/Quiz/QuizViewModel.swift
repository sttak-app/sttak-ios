import SwiftUI

/// 퀴즈 진행 상태. playing(문제별 채점·해설) → done(결과·보상) → cooldown(다음 세트 카운트다운).
@MainActor
@Observable
final class QuizViewModel {
    enum Phase: Equatable {
        case loading
        case playing
        case done
        case cooldown
        case failed(String)
    }

    struct AnswerRecord {
        let selected: Int
        let isCorrect: Bool
    }

    private(set) var phase: Phase = .loading
    private(set) var questions: [QuizQuestion] = []
    private(set) var currentIndex = 0
    private(set) var selectedOption: Int?
    private(set) var isRevealed = false
    private(set) var records: [AnswerRecord] = []
    private(set) var outcome: QuizOutcome?
    private(set) var lastCompletion: QuizCompletion?
    private(set) var nextAvailableAt: Date?
    private(set) var currentCapital = 0
    private(set) var now = Date()

    private var quizSet: QuizSet?
    private let score: ScoreQuizAndAwardCapital
    private let quiz: QuizRepository
    private let portfolio: PortfolioRepository
    private var tickTask: Task<Void, Never>?

    init(score: ScoreQuizAndAwardCapital, quiz: QuizRepository, portfolio: PortfolioRepository) {
        self.score = score
        self.quiz = quiz
        self.portfolio = portfolio
    }

    // MARK: 파생
    var currentQuestion: QuizQuestion? {
        questions.indices.contains(currentIndex) ? questions[currentIndex] : nil
    }
    var totalCount: Int { questions.count }
    var progressNumberText: String { "\(min(currentIndex + 1, totalCount))/\(totalCount)" }
    var wasCurrentCorrect: Bool { isRevealed && selectedOption == currentQuestion?.answerIndex }
    var isLastQuestion: Bool { currentIndex >= totalCount - 1 }

    var primaryButtonLabel: String {
        if !isRevealed { return "정답 확인" }
        return isLastQuestion ? "결과 보기" : "다음 문제"
    }
    var primaryButtonEnabled: Bool { isRevealed || selectedOption != nil }

    /// 결과 화면용 문항별 정/오답 recap.
    var recap: [(index: Int, isCorrect: Bool, title: String)] {
        records.enumerated().map { i, record in
            (i, record.isCorrect, questions[safe: i]?.question ?? "")
        }
    }

    // MARK: 로드
    func load() async {
        phase = .loading
        do {
            currentCapital = (try? await portfolio.fetchPortfolio())?.cash.amount ?? 0
            let last = try await quiz.lastCompletion()
            now = Date()
            if let last, !ScoreQuizAndAwardCapital.canTake(lastTakenAt: last.takenAt, now: now) {
                lastCompletion = last
                nextAvailableAt = ScoreQuizAndAwardCapital.nextAvailableAt(after: last.takenAt)
                phase = .cooldown
                startTicking()
            } else {
                let set = try await quiz.currentQuizSet()
                quizSet = set
                questions = set.questions
                currentIndex = 0; selectedOption = nil; isRevealed = false; records = []
                phase = .playing
            }
        } catch {
            phase = .failed("퀴즈를 불러오지 못했어요.")
        }
    }

    func selectOption(_ index: Int) {
        guard !isRevealed else { return }
        selectedOption = index
    }

    /// 정답 확인 → (다음 / 결과 보기).
    func primaryAction() async {
        if !isRevealed {
            guard let selected = selectedOption, let question = currentQuestion else { return }
            records.append(AnswerRecord(selected: selected, isCorrect: selected == question.answerIndex))
            isRevealed = true
        } else if isLastQuestion {
            await finish()
        } else {
            currentIndex += 1
            selectedOption = nil
            isRevealed = false
        }
    }

    func stopTicking() { tickTask?.cancel() }

    #if DEBUG
    func debugResetCooldown() async {
        try? await quiz.debugClearCooldown()
        await load()
    }
    #endif

    // MARK: 내부
    private func finish() async {
        guard let quizSet else { return }
        do {
            let result = try await score(quizSet: quizSet, selectedAnswers: records.map(\.selected), now: Date())
            outcome = result
            nextAvailableAt = result.nextAvailableAt
            currentCapital = (try? await portfolio.fetchPortfolio())?.cash.amount ?? currentCapital
            now = Date()
            phase = .done
            startTicking()
        } catch {
            phase = .failed("결과 저장에 실패했어요.")
        }
    }

    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.now = Date()
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
