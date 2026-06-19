import Foundation

/// 랭킹 정렬 기준.
enum RankingMode: Sendable, Equatable, CaseIterable {
    case asset   // 보유 자산
    case points  // 누적 포인트
}

/// 랭킹 한 행. (자산·포인트 값을 모두 보유 — 어느 값을 보여줄지는 mode/표현 계층)
struct RankingEntry: Sendable, Equatable {
    let rank: Int
    let nickname: String
    let league: League
    let assetValue: Money    // 보유 자산
    let points: Int          // 누적 포인트
    let rankChange: Int      // 1시간 전 대비 변동 (+상승 / -하락 / 0 유지)
    let isCurrentUser: Bool  // 내 행 여부
}
