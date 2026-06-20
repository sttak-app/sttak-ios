import Foundation

/// 퀴즈 Mock. 문제는 고정 fixture, 결과 기록(포인트·쿨다운)은 공유 store. 자본금은 PortfolioRepository.
struct MockQuizRepository: QuizRepository {
    let store: MockLocalStore

    func currentQuizSet() async throws -> QuizSet {
        QuizSet(id: "quiz-current", questions: MockData.quizQuestions, takenAt: nil, correctCount: nil, earnedCapital: nil)
    }

    func lastCompletion() async throws -> QuizCompletion? {
        await store.lastQuizCompletion
    }

    func recordResult(correctCount: Int, earnedCapital: Money, takenAt: Date) async throws {
        await store.recordQuizResult(correctCount: correctCount, earnedCapital: earnedCapital, takenAt: takenAt)
    }

    #if DEBUG
    func debugClearCooldown() async throws {
        await store.clearQuizCooldown()
    }
    #endif
}
