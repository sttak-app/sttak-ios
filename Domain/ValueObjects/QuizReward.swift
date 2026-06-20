import Foundation

/// 퀴즈 보상·쿨다운 규칙. 단일 출처.
/// (제품 결정: 보상은 단일 통화=자본금 한 가지. 별도 포인트 적립 없음.)
enum QuizReward {
    /// 정답 1문제당 모의투자 자본금(원).
    static let capitalPerCorrect = 500_000
    /// 다음 세트까지 쿨다운(6시간).
    static let cooldown: TimeInterval = 6 * 60 * 60
}
