import Foundation

/// 시점별 랭킹 목록(서버 산출). 보유 자산 단일 리더보드.
struct RankingSnapshot: Sendable, Equatable, Identifiable {
    let id: String
    let entries: [RankingEntry]   // 보유 자산 내림차순, rank 매겨짐
    let updatedAt: Date
}
