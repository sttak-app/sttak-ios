import Foundation

/// 퀴즈 보상·쿨다운 규칙. 단일 출처.
/// (제품 결정: 보상은 단일 통화=자본금 한 가지. 별도 포인트 적립 없음.)
/// Live에선 서버가 이 규칙의 SSOT — 아래 상수·판정은 Mock 재현과 표현(진행바 등)에 쓴다.
enum QuizReward {
    /// 정답 1문제당 모의투자 자본금(원).
    static let capitalPerCorrect = 500_000
    /// 다음 세트까지 쿨다운(6시간).
    static let cooldown: TimeInterval = 6 * 60 * 60

    // MARK: 쿨다운 경계(순수 판정 — Mock·테스트용. 정각 포함 정책)

    /// 마지막 응시 + 6h 이후면 새 세트 가능(정각 포함).
    static func canTake(lastTakenAt: Date?, now: Date) -> Bool {
        guard let last = lastTakenAt else { return true }
        return now >= last.addingTimeInterval(cooldown)
    }

    static func nextAvailableAt(after lastTakenAt: Date) -> Date {
        lastTakenAt.addingTimeInterval(cooldown)
    }
}
