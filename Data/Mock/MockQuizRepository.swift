import Foundation

/// 퀴즈 Mock. 채점 시 정답 수만큼 자본금(+50만)과 포인트(+50)를 공유 store에 적립한다.
struct MockQuizRepository: QuizRepository {
    let store: MockLocalStore

    func currentQuizSet() async throws -> QuizSet {
        QuizSet(
            id: "quiz-current",
            questions: MockData.quizQuestions,
            takenAt: nil,
            correctCount: nil,
            earnedCapital: nil
        )
    }

    func submit(quizSetID: String, selectedAnswers: [Int]) async throws -> QuizSet {
        let questions = MockData.quizQuestions
        let correctCount = zip(selectedAnswers, questions).reduce(into: 0) { count, pair in
            if pair.0 == pair.1.answerIndex { count += 1 }
        }
        let earned = correctCount * MockData.quizReward

        await store.addCapital(earned)
        await store.addPoints(correctCount * MockData.quizPointsPerCorrect)
        await store.markQuizTaken(at: Date())

        return QuizSet(
            id: quizSetID,
            questions: questions,
            takenAt: Date(),
            correctCount: correctCount,
            earnedCapital: .krw(earned)
        )
    }
}
