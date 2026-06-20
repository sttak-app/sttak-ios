import Foundation

/// 랭킹 Mock(확정 C6: 다른 유저는 모의 데이터). 보유 자산 내림차순 단일 리더보드.
/// 내 순위 합성(myAsset)은 표현/UseCase 계층의 몫.
struct MockRankingRepository: RankingRepository {
    func fetchRanking() async throws -> RankingSnapshot {
        let names = MockData.rankingNames
        let changes = MockData.rankingChanges
        let assets = MockData.rankingAssetTop
        let count = min(names.count, assets.count, changes.count)

        let entries = (0..<count).map { i in
            RankingEntry(
                rank: i + 1,
                nickname: names[i],
                assetValue: .krw(assets[i]),
                rankChange: changes[i],
                isCurrentUser: false
            )
        }

        return RankingSnapshot(id: "ranking", entries: entries, updatedAt: Date())
    }
}
