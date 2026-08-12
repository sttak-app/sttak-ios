import Foundation

/// 랭킹 Live. 보유 자산 기준 상위 100 리더보드(공개) + 권위있는 내 순위(JWT).
/// 매핑: GET /api/v1/ranking, GET /api/v1/ranking/me.
struct LiveRankingRepository: RankingRepository {
    let api: APIClient

    func fetchRanking() async throws -> RankingSnapshot {
        let dto: RankingSnapshotDTO = try await api.request(.get("/api/v1/ranking"))
        return dto.toDomain()
    }

    func fetchMyRanking() async throws -> MyRanking? {
        do {
            let dto: MyRankingDTO = try await api.request(.get("/api/v1/ranking/me"))
            return dto.toDomain()
        } catch RepositoryError.notFound {
            return nil   // 계좌 없음(404) → 호출부가 로컬 합성으로 대체
        }
    }
}
