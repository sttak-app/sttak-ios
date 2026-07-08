import SwiftUI

/// 퀴즈 진행 상태. 문항별 제출·채점(서버 SSOT) → done(결과·보상) → cooldown(다음 세트 카운트다운).
/// 정답·해설·적립액은 제출 응답에서 받고, 쿨다운 시각도 서버 값을 그대로 쓴다.
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

    /// 제출 후 공개된 채점 정보(현재 문항).
    struct RevealedAnswer: Equatable {
        let selected: Int
        let correctIndex: Int
        let isCorrect: Bool
        let explanation: String
        let earnedCapital: Money
    }

    /// 이번 세션에서 푼 문항 recap(결과 화면).
    struct AnswerRecord: Equatable {
        let title: String
        let isCorrect: Bool
    }

    private(set) var phase: Phase = .loading
    private(set) var currentQuestion: PendingQuizQuestion?
    private(set) var currentIndex = 0            // 지금 풀고 있는 문항의 사이클 내 위치(0-based)
    private(set) var totalCount = 3
    private(set) var selectedOption: Int?
    private(set) var revealedAnswer: RevealedAnswer?
    private(set) var records: [AnswerRecord] = []
    private(set) var outcome: QuizCompletion?    // 완료 직후 결과(서버 last 기준)
    private(set) var lastCompletion: QuizCompletion?
    private(set) var nextAvailableAt: Date?
    private(set) var currentCapital = 0
    private(set) var now = Date()

    private var lastResult: QuizAnswerResult?
    private let quiz: QuizRepository
    private let portfolio: PortfolioRepository
    private var tickTask: Task<Void, Never>?

    init(quiz: QuizRepository, portfolio: PortfolioRepository) {
        self.quiz = quiz
        self.portfolio = portfolio
    }

    // MARK: 파생
    var isRevealed: Bool { revealedAnswer != nil }
    var progressNumberText: String { "\(min(currentIndex + 1, totalCount))/\(totalCount)" }
    var wasCurrentCorrect: Bool { revealedAnswer?.isCorrect == true }
    var isLastQuestion: Bool { lastResult?.completed ?? (currentIndex >= totalCount - 1) }

    var primaryButtonLabel: String {
        if !isRevealed { return "정답 확인" }
        return isLastQuestion ? "결과 보기" : "다음 문제"
    }
    var primaryButtonEnabled: Bool { isRevealed || selectedOption != nil }

    /// 결과 화면용 문항별 정/오답 recap(이번 세션에서 푼 문항).
    var recap: [(index: Int, isCorrect: Bool, title: String)] {
        records.enumerated().map { i, record in (i, record.isCorrect, record.title) }
    }

    // MARK: 로드
    func load() async {
        phase = .loading
        do {
            currentCapital = (try? await portfolio.fetchPortfolio())?.cash.amount ?? 0
            lastCompletion = try? await quiz.lastCompletion()
            now = Date()
            switch try await quiz.nextQuestion() {
            case let .cooldown(nextAt):
                // 서버가 쿨다운의 SSOT — 로컬 6시간 계산 대신 응답 값을 쓴다.
                nextAvailableAt = nextAt
                phase = .cooldown
                startTicking()
            case let .question(question, answeredInCycle, totalInCycle):
                currentQuestion = question
                currentIndex = answeredInCycle
                totalCount = totalInCycle
                selectedOption = nil
                revealedAnswer = nil
                lastResult = nil
                records = []
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

    /// 정답 확인(제출·채점) → (다음 문제 / 결과 보기).
    func primaryAction() async {
        if !isRevealed {
            await submitCurrent()
        } else if isLastQuestion {
            await finish()
        } else {
            await advance()
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
    private func submitCurrent() async {
        guard let selected = selectedOption, let question = currentQuestion else { return }
        do {
            let result = try await quiz.submitAnswer(quizId: question.id, selectedIndex: selected)
            lastResult = result
            totalCount = result.totalInCycle
            revealedAnswer = RevealedAnswer(
                selected: selected,
                correctIndex: result.correctIndex,
                isCorrect: result.isCorrect,
                explanation: result.explanation,
                earnedCapital: result.earnedCapital
            )
            records.append(AnswerRecord(title: question.question, isCorrect: result.isCorrect))
            if let nextAt = result.nextAvailableAt { nextAvailableAt = nextAt }
            // 적립은 서버(또는 Mock store)가 수행 — 배너 금액만 갱신.
            currentCapital = (try? await portfolio.fetchPortfolio())?.cash.amount ?? currentCapital
        } catch {
            phase = .failed("답안을 제출하지 못했어요.")
        }
    }

    private func advance() async {
        do {
            switch try await quiz.nextQuestion() {
            case let .question(question, answeredInCycle, totalInCycle):
                currentQuestion = question
                currentIndex = answeredInCycle
                totalCount = totalInCycle
                selectedOption = nil
                revealedAnswer = nil
            case let .cooldown(nextAt):
                // 진행 중 서버가 쿨다운으로 판정(경계 상황) → 결과 화면으로.
                nextAvailableAt = nextAt
                await finish()
            }
        } catch {
            phase = .failed("다음 문제를 불러오지 못했어요.")
        }
    }

    private func finish() async {
        // 완료 요약은 서버 기록(last)이 원본. 실패 시 세션 누적으로 폴백.
        let sessionCorrect = records.filter(\.isCorrect).count
        let sessionEarned = sessionCorrect * QuizReward.capitalPerCorrect
        let last = try? await quiz.lastCompletion()
        outcome = last ?? QuizCompletion(
            takenAt: Date(),
            correctCount: sessionCorrect,
            earnedCapital: .krw(sessionEarned)
        )
        lastCompletion = outcome
        if nextAvailableAt == nil, let takenAt = outcome?.takenAt {
            nextAvailableAt = QuizReward.nextAvailableAt(after: takenAt)
        }
        currentCapital = (try? await portfolio.fetchPortfolio())?.cash.amount ?? currentCapital
        now = Date()
        phase = .done
        startTicking()
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
