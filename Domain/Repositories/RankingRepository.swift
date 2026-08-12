import Foundation

/// 랭킹(서버 산출). 보유 자산 단일 리더보드 + 권위있는 내 순위 요약.
/// 매핑: fetchRanking=GET /ranking, fetchMyRanking=GET /ranking/me.
protocol RankingRepository: Sendable {
    /// 보유 자산 기준 상위 리더보드 스냅샷.
    func fetchRanking() async throws -> RankingSnapshot
    /// 서버가 산출한 내 순위 요약. 계좌가 없으면(404) nil → 호출부가 로컬 합성으로 대체.
    func fetchMyRanking() async throws -> MyRanking?
}
