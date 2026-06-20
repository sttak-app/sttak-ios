import XCTest
@testable import sttak

/// 퀴즈 채점·자본금 적립 + 쿨다운 경계. 실제 ScoreQuizAndAwardCapital + creditCash 호출(재mock 없음).
/// 기대값은 손계산 독립 앵커(자기참조 금지). now/lastTakenAt 주입으로 결정적.
final class QuizScoringTests: XCTestCase {

    /// 정답 N개가 되도록 답안 구성(앞 N개 정답, 나머지 오답).
    private func answers(correct n: Int, _ set: QuizSet) -> [Int] {
        set.questions.enumerated().map { index, question in
            index < n ? question.answerIndex : (question.answerIndex + 1) % question.options.count
        }
    }

    private func makeSystem(cash: Int = 10_000_000) -> (ScoreQuizAndAwardCapital, MockPortfolioRepository, MockQuizRepository) {
        let store = MockLocalStore(cash: cash)
        let portfolio = MockPortfolioRepository(store: store)
        let quiz = MockQuizRepository(store: store)
        return (ScoreQuizAndAwardCapital(portfolio: portfolio, quiz: quiz), portfolio, quiz)
    }

    // MARK: 채점 → 자본금 (정답수 × 500,000)

    func testScore_capitalAndCash_byCorrectCount() async throws {
        // 앵커: 0→0, 1→50만, 2→100만, 3→150만. 현금은 그만큼 증가.
        let cases: [(correct: Int, earned: Int, cash: Int)] = [
            (0, 0, 10_000_000),
            (1, 500_000, 10_500_000),
            (2, 1_000_000, 11_000_000),
            (3, 1_500_000, 11_500_000),
        ]
        for c in cases {
            let (score, portfolio, quiz) = makeSystem(cash: 10_000_000)
            let set = try await quiz.currentQuizSet()
            let outcome = try await score(
                quizSet: set, selectedAnswers: answers(correct: c.correct, set),
                now: Date(timeIntervalSince1970: 1_000_000)
            )
            XCTAssertEqual(outcome.correctCount, c.correct)
            XCTAssertEqual(outcome.earnedCapital.amount, c.earned, "정답 \(c.correct)개")
            let p = try await portfolio.fetchPortfolio()
            XCTAssertEqual(p.cash.amount, c.cash, "정답 \(c.correct)개 현금")
        }
    }

    func testScore_recordsCompletion_andNextAvailable() async throws {
        let (score, _, quiz) = makeSystem()
        let set = try await quiz.currentQuizSet()
        let now = Date(timeIntervalSince1970: 1_000_000)
        let outcome = try await score(quizSet: set, selectedAnswers: answers(correct: 3, set), now: now)

        // 다음 가능 = now + 6h (21,600s)
        XCTAssertEqual(outcome.nextAvailableAt, now.addingTimeInterval(21_600))
        // 지난 세트 기록 보관(쿨다운 화면용)
        let last = try await quiz.lastCompletion()
        XCTAssertEqual(last?.correctCount, 3)
        XCTAssertEqual(last?.earnedCapital.amount, 1_500_000)
        XCTAssertEqual(last?.takenAt, now)
    }

    // MARK: 쿨다운 경계 (가장 중요 — 정각 포함 정책 못 박기)

    func testCooldown_boundaryPolicy() {
        let sixHours: TimeInterval = 6 * 60 * 60 // 21,600초 (독립 손계산)
        XCTAssertEqual(QuizReward.cooldown, sixHours) // 정책 상수 고정

        let T = Date(timeIntervalSince1970: 1_000_000)

        // 응시 이력 없음 → 가능
        XCTAssertTrue(ScoreQuizAndAwardCapital.canTake(lastTakenAt: nil, now: T))

        // 막 응시(now == T) → 불가
        XCTAssertFalse(ScoreQuizAndAwardCapital.canTake(lastTakenAt: T, now: T))
        // 직전(T+6h−1s) → 불가
        XCTAssertFalse(ScoreQuizAndAwardCapital.canTake(lastTakenAt: T, now: T.addingTimeInterval(sixHours - 1)))
        // 정각(T+6h) → 가능 (>= 정책: 정각 포함)
        XCTAssertTrue(ScoreQuizAndAwardCapital.canTake(lastTakenAt: T, now: T.addingTimeInterval(sixHours)))
        // 직후(T+6h+1s) → 가능
        XCTAssertTrue(ScoreQuizAndAwardCapital.canTake(lastTakenAt: T, now: T.addingTimeInterval(sixHours + 1)))

        // 다음 가능 시각 == T + 6h
        XCTAssertEqual(ScoreQuizAndAwardCapital.nextAvailableAt(after: T), T.addingTimeInterval(sixHours))
    }
}
