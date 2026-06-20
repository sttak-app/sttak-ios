import Foundation

/// 랭킹(서버 산출, MVP는 Mock 데이터 — 확정 C6).
/// 매핑: GET /ranking?mode=asset|points.
protocol RankingRepository: Sendable {
    /// 선택한 기준(자산/포인트)의 랭킹 스냅샷.
    func fetchRanking(mode: RankingMode) async throws -> RankingSnapshot
}
