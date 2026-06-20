import Foundation

/// 퀴즈 결과(채점+보상). 보상은 단일 통화=자본금.
struct QuizOutcome: Sendable, Equatable {
    let correctCount: Int
    let earnedCapital: Money
    let takenAt: Date
    let nextAvailableAt: Date
}

/// ★ 채점 → 자본금 적립 → 쿨다운 설정. 규칙·오케스트레이션만 담당.
/// 자본금은 PortfolioRepository(현금 증가)로, 쿨다운은 QuizRepository로 반영(재구현 없음).
struct ScoreQuizAndAwardCapital: Sendable {
    let portfolio: PortfolioRepository
    let quiz: QuizRepository

    func callAsFunction(quizSet: QuizSet, selectedAnswers: [Int], now: Date) async throws -> QuizOutcome {
        let correct = zip(quizSet.questions, selectedAnswers).reduce(into: 0) { count, pair in
            if pair.0.answerIndex == pair.1 { count += 1 }
        }
        let capital = correct * QuizReward.capitalPerCorrect

        if capital > 0 {
            try await portfolio.creditCash(.krw(capital))
        }
        try await quiz.recordResult(correctCount: correct, earnedCapital: .krw(capital), takenAt: now)

        return QuizOutcome(
            correctCount: correct,
            earnedCapital: .krw(capital),
            takenAt: now,
            nextAvailableAt: Self.nextAvailableAt(after: now)
        )
    }

    // MARK: 쿨다운 경계(순수, 커밋 18 테스트)

    /// 마지막 응시 + 6h 이후면 새 세트 가능.
    static func canTake(lastTakenAt: Date?, now: Date) -> Bool {
        guard let last = lastTakenAt else { return true }
        return now >= last.addingTimeInterval(QuizReward.cooldown)
    }

    static func nextAvailableAt(after lastTakenAt: Date) -> Date {
        lastTakenAt.addingTimeInterval(QuizReward.cooldown)
    }
}
