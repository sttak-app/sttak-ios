import Foundation

/// 퀴즈 Mock — 서버의 문항별 채점 흐름(next/submit/last)을 고정 fixture + 공유 store로 재현.
/// 정답 보상은 서버처럼 submit 시점에 store 현금으로 적립한다. now 주입으로 테스트 결정적.
struct MockQuizRepository: QuizRepository {
    let store: MockLocalStore
    /// 시간 주입(쿨다운 경계 테스트용). 기본은 현재 시각.
    var now: @Sendable () -> Date = { Date() }

    private var questions: [QuizQuestion] { MockData.quizQuestions }
    private static let quizIdPrefix = "mock-quiz-"

    func nextQuestion() async throws -> QuizNextState {
        let currentTime = now()
        if let last = await store.quizLastTakenAt,
           !QuizReward.canTake(lastTakenAt: last, now: currentTime) {
            return .cooldown(nextAvailableAt: QuizReward.nextAvailableAt(after: last))
        }
        let answered = await store.quizCycleAnswered
        guard answered < questions.count else {
            // 도달 불가 방어: 사이클은 3문항 제출 시점에 완료·리셋된다.
            throw RepositoryError.unknown
        }
        let fixture = questions[answered]
        let pending = PendingQuizQuestion(
            id: "\(Self.quizIdPrefix)\(answered)",
            question: fixture.question,
            options: fixture.options,
            category: fixture.category
        )
        return .question(pending, answeredInCycle: answered, totalInCycle: questions.count)
    }

    func submitAnswer(quizId: String, selectedIndex: Int) async throws -> QuizAnswerResult {
        guard let index = Int(quizId.dropFirst(Self.quizIdPrefix.count)),
              quizId.hasPrefix(Self.quizIdPrefix),
              questions.indices.contains(index) else {
            throw RepositoryError.notFound
        }
        let fixture = questions[index]
        guard fixture.options.indices.contains(selectedIndex) else {
            throw RepositoryError.validation(message: "선택지가 올바르지 않아요.")
        }

        let isCorrect = selectedIndex == fixture.answerIndex
        let reward = isCorrect ? QuizReward.capitalPerCorrect : 0
        await store.recordQuizAnswer(isCorrect: isCorrect, reward: reward)

        let answered = await store.quizCycleAnswered
        let completed = answered >= questions.count
        let takenAt = now()
        if completed {
            await store.completeQuizCycle(takenAt: takenAt)
        }

        return QuizAnswerResult(
            quizId: quizId,
            selectedIndex: selectedIndex,
            correctIndex: fixture.answerIndex,
            isCorrect: isCorrect,
            explanation: fixture.explanation,
            earnedCapital: .krw(reward),
            answeredInCycle: answered,
            totalInCycle: questions.count,
            completed: completed,
            nextAvailableAt: completed ? QuizReward.nextAvailableAt(after: takenAt) : nil
        )
    }

    func lastCompletion() async throws -> QuizCompletion? {
        await store.lastQuizCompletion
    }

    #if DEBUG
    func debugClearCooldown() async throws {
        await store.clearQuizCooldown()
    }
    #endif
}
