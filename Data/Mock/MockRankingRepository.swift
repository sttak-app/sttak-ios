import Foundation

/// 랭킹 Mock(확정 C6: 다른 유저는 모의 데이터). 자산/포인트 배열은 이미 내림차순.
/// 리그는 각 행의 포인트로 산출. 내 순위 합성(myAsset/myPoints)은 표현/UseCase 계층의 몫.
struct MockRankingRepository: RankingRepository {
    func fetchRanking(mode: RankingMode) async throws -> RankingSnapshot {
        let names = MockData.rankingNames
        let changes = MockData.rankingChanges
        let assets = MockData.rankingAssetTop
        let points = MockData.rankingPointTop
        let count = min(names.count, assets.count, points.count, changes.count)

        let entries = (0..<count).map { i in
            RankingEntry(
                rank: i + 1,
                nickname: names[i],
                league: MockData.league(forPoints: points[i]),
                assetValue: .krw(assets[i]),
                points: points[i],
                rankChange: changes[i],
                isCurrentUser: false
            )
        }

        return RankingSnapshot(
            id: "ranking-\(mode)",
            mode: mode,
            entries: entries,
            updatedAt: Date()
        )
    }
}
