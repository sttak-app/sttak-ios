import Foundation

/// 랭킹 한 행. 단일 통화·단일 리더보드(보유 자산). (제품 결정: 포인트 랭킹·League 미사용)
struct RankingEntry: Sendable, Equatable {
    let rank: Int
    let nickname: String
    let assetValue: Money    // 보유 자산
    let rankChange: Int      // 1시간 전 대비 변동 (+상승 / -하락 / 0 유지)
    let isCurrentUser: Bool  // 내 행 여부
}
