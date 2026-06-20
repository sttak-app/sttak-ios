import XCTest
@testable import sttak

/// 내 순위 합성(순수 함수). 손계산 독립 앵커.
final class RankingPlacementTests: XCTestCase {

    private func entry(rank: Int, asset: Int) -> RankingEntry {
        RankingEntry(rank: rank, nickname: "u\(rank)", assetValue: .krw(asset), rankChange: 0, isCurrentUser: false)
    }

    /// 자산 내림차순 3명: 16M, 14M, 12M.
    private let board = [
        RankingEntry(rank: 1, nickname: "a", assetValue: .krw(16_000_000), rankChange: 0, isCurrentUser: false),
        RankingEntry(rank: 2, nickname: "b", assetValue: .krw(14_000_000), rankChange: 0, isCurrentUser: false),
        RankingEntry(rank: 3, nickname: "c", assetValue: .krw(12_000_000), rankChange: 0, isCurrentUser: false),
    ]

    func testBelowEveryone_isLast() {
        // 내 자산 10M < 모든 랭커 → 위에 3명 → 4위, 전체 4명.
        let r = RankingPlacement.locate(myAsset: .krw(10_000_000), in: board)
        XCTAssertEqual(r.rank, 4)
        XCTAssertEqual(r.totalUsers, 4)
    }

    func testMiddle_insertsByAsset() {
        // 13M: 위에 2명(16M,14M) → 3위.
        XCTAssertEqual(RankingPlacement.locate(myAsset: .krw(13_000_000), in: board).rank, 3)
    }

    func testAboveEveryone_isFirst() {
        // 20M: 위에 0명 → 1위.
        XCTAssertEqual(RankingPlacement.locate(myAsset: .krw(20_000_000), in: board).rank, 1)
    }

    func testTie_existingRankerFirst() {
        // 14M 동률: strictly greater(16M)만 위 → 2위(기존 14M 랭커가 앞).
        XCTAssertEqual(RankingPlacement.locate(myAsset: .krw(14_000_000), in: board).rank, 2)
    }

    func testEmptyBoard_isFirstOfOne() {
        let r = RankingPlacement.locate(myAsset: .krw(10_000_000), in: [])
        XCTAssertEqual(r.rank, 1)
        XCTAssertEqual(r.totalUsers, 1)
    }
}
