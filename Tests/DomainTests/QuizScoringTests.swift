import XCTest
@testable import sttak

/// 퀴즈 문항별 채점·자본금 적립 + 쿨다운 경계. 실제 MockQuizRepository(공유 store) 사용(재mock 없음).
/// 기대값은 손계산 독립 앵커(자기참조 금지). now 주입으로 결정적.
final class QuizScoringTests: XCTestCase {

    private let fixedNow = Date(timeIntervalSince1970: 1_000_000)

    private func makeSystem(cash: Int = 10_000_000) -> (MockQuizRepository, MockPortfolioRepository) {
        let store = MockLocalStore(cash: cash)
        let now = fixedNow
        let quiz = MockQuizRepository(store: store, now: { now })
        return (quiz, MockPortfolioRepository(store: store))
    }

    /// 3문항을 앞에서부터 n개 정답, 나머지 오답으로 제출.
    private func playCycle(correct n: Int, quiz: MockQuizRepository) async throws -> [QuizAnswerResult] {
        var results: [QuizAnswerResult] = []
        for i in 0..<MockData.quizQuestions.count {
            guard case let .question(pending, answeredInCycle, _) = try await quiz.nextQuestion() else {
                XCTFail("문항 \(i)에서 쿨다운이 반환됨")
                return results
            }
            XCTAssertEqual(answeredInCycle, i)
            let answer = MockData.quizQuestions[i].answerIndex
            let selected = i < n ? answer : (answer + 1) % pending.options.count
            results.append(try await quiz.submitAnswer(quizId: pending.id, selectedIndex: selected))
        }
        return results
    }

    // MARK: 문항별 채점 → 자본금 (정답수 × 500,000)

    func testSubmit_capitalAndCash_byCorrectCount() async throws {
        // 앵커: 0→0, 1→50만, 2→100만, 3→150만. 현금은 그만큼 증가.
        let cases: [(correct: Int, earned: Int, cash: Int)] = [
            (0, 0, 10_000_000),
            (1, 500_000, 10_500_000),
            (2, 1_000_000, 11_000_000),
            (3, 1_500_000, 11_500_000),
        ]
        for c in cases {
            let (quiz, portfolio) = makeSystem(cash: 10_000_000)
            let results = try await playCycle(correct: c.correct, quiz: quiz)

            XCTAssertEqual(results.filter(\.isCorrect).count, c.correct)
            let totalEarned = results.reduce(0) { $0 + $1.earnedCapital.amount }
            XCTAssertEqual(totalEarned, c.earned, "정답 \(c.correct)개")

            let p = try await portfolio.fetchPortfolio()
            XCTAssertEqual(p.cash.amount, c.cash, "정답 \(c.correct)개 현금")
        }
    }

    func testSubmit_perQuestionResult_revealsAnswerAndExplanation() async throws {
        let (quiz, _) = makeSystem()
        guard case let .question(pending, _, total) = try await quiz.nextQuestion() else {
            return XCTFail("첫 문항이 없음")
        }
        XCTAssertEqual(total, 3)

        // 오답 제출 — 서버(재현)가 정답 인덱스·해설을 공개하고 적립 0.
        let fixture = MockData.quizQuestions[0]
        let wrong = (fixture.answerIndex + 1) % fixture.options.count
        let result = try await quiz.submitAnswer(quizId: pending.id, selectedIndex: wrong)
        XCTAssertFalse(result.isCorrect)
        XCTAssertEqual(result.correctIndex, fixture.answerIndex)
        XCTAssertEqual(result.explanation, fixture.explanation)
        XCTAssertEqual(result.earnedCapital.amount, 0)
        XCTAssertEqual(result.answeredInCycle, 1)
        XCTAssertFalse(result.completed)
        XCTAssertNil(result.nextAvailableAt)
    }

    func testCompletion_recordsLast_andNextAvailable() async throws {
        let (quiz, _) = makeSystem()
        let results = try await playCycle(correct: 3, quiz: quiz)

        // 마지막 문항에서 완료 + 다음 가능 = now + 6h (21,600s).
        XCTAssertTrue(results[2].completed)
        XCTAssertEqual(results[2].nextAvailableAt, fixedNow.addingTimeInterval(21_600))

        // 지난 세트 기록 보관(쿨다운 화면용).
        let last = try await quiz.lastCompletion()
        XCTAssertEqual(last?.correctCount, 3)
        XCTAssertEqual(last?.earnedCapital.amount, 1_500_000)
        XCTAssertEqual(last?.takenAt, fixedNow)

        // 완료 직후 next는 쿨다운.
        guard case let .cooldown(nextAt) = try await quiz.nextQuestion() else {
            return XCTFail("완료 직후인데 쿨다운이 아님")
        }
        XCTAssertEqual(nextAt, fixedNow.addingTimeInterval(21_600))
    }

    // MARK: 쿨다운 경계 (가장 중요 — 정각 포함 정책 못 박기)

    func testCooldown_boundaryPolicy() {
        let sixHours: TimeInterval = 6 * 60 * 60 // 21,600초 (독립 손계산)
        XCTAssertEqual(QuizReward.cooldown, sixHours) // 정책 상수 고정

        let T = Date(timeIntervalSince1970: 1_000_000)

        // 응시 이력 없음 → 가능
        XCTAssertTrue(QuizReward.canTake(lastTakenAt: nil, now: T))

        // 막 응시(now == T) → 불가
        XCTAssertFalse(QuizReward.canTake(lastTakenAt: T, now: T))
        // 직전(T+6h−1s) → 불가
        XCTAssertFalse(QuizReward.canTake(lastTakenAt: T, now: T.addingTimeInterval(sixHours - 1)))
        // 정각(T+6h) → 가능 (>= 정책: 정각 포함)
        XCTAssertTrue(QuizReward.canTake(lastTakenAt: T, now: T.addingTimeInterval(sixHours)))
        // 직후(T+6h+1s) → 가능
        XCTAssertTrue(QuizReward.canTake(lastTakenAt: T, now: T.addingTimeInterval(sixHours + 1)))

        // 다음 가능 시각 == T + 6h
        XCTAssertEqual(QuizReward.nextAvailableAt(after: T), T.addingTimeInterval(sixHours))
    }
}
