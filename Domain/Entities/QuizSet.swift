import Foundation

/// 6시간 주기로 생성되는 3문제 세트. 응시 전에는 결과 필드가 nil.
/// (sttak_quiz_last/lastscore/lastearned 와 교차검증)
struct QuizSet: Sendable, Equatable, Identifiable {
    let id: String
    let questions: [QuizQuestion]  // 3문제
    let takenAt: Date?             // 응시 시각 (미응시 nil)
    let correctCount: Int?         // 정답 수
    let earnedCapital: Money?      // 적립 자본금
}
