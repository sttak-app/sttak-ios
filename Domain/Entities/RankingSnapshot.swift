import Foundation

/// 시점별 랭킹 목록(서버 산출). 정렬 기준(mode)에 맞춰 rank가 매겨진 entries를 보유한다.
struct RankingSnapshot: Sendable, Equatable, Identifiable {
    let id: String
    let mode: RankingMode       // 이 스냅샷의 정렬 기준
    let entries: [RankingEntry]
    let updatedAt: Date
}
