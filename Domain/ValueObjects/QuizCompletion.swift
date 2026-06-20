import Foundation

/// 마지막으로 푼 퀴즈 결과(쿨다운 판정·지난 세트 요약용).
struct QuizCompletion: Sendable, Equatable {
    let takenAt: Date
    let correctCount: Int
    let earnedCapital: Money
}
