import Foundation

/// 랭킹(서버 산출, MVP는 Mock 데이터 — 확정 C6). 보유 자산 단일 리더보드.
/// 매핑: GET /ranking.
protocol RankingRepository: Sendable {
    /// 보유 자산 기준 랭킹 스냅샷.
    func fetchRanking() async throws -> RankingSnapshot
}
