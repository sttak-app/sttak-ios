import XCTest
@testable import sttak

/// League 임계 경계값(MockData.league) + Comparable 순서. 손계산 경계 앵커.
final class LeagueTests: XCTestCase {

    // 임계: 브론즈 0–500, 실버 500–1000, 골드 1000–2000, 플래티넘 2000–3500, 다이아 3500+
    func testLeagueThresholds_boundaries() {
        XCTAssertEqual(MockData.league(forPoints: 0), .bronze)
        XCTAssertEqual(MockData.league(forPoints: 499), .bronze)
        XCTAssertEqual(MockData.league(forPoints: 500), .silver)   // 경계 포함
        XCTAssertEqual(MockData.league(forPoints: 999), .silver)
        XCTAssertEqual(MockData.league(forPoints: 1_000), .gold)
        XCTAssertEqual(MockData.league(forPoints: 1_999), .gold)
        XCTAssertEqual(MockData.league(forPoints: 2_000), .platinum)
        XCTAssertEqual(MockData.league(forPoints: 3_499), .platinum)
        XCTAssertEqual(MockData.league(forPoints: 3_500), .diamond)
        XCTAssertEqual(MockData.league(forPoints: 9_999), .diamond)
    }

    func testLeague_comparableOrder() {
        XCTAssertTrue(League.bronze < League.silver)
        XCTAssertTrue(League.silver < League.gold)
        XCTAssertTrue(League.gold < League.platinum)
        XCTAssertTrue(League.platinum < League.diamond)
        XCTAssertEqual(League.allCases.sorted(), [.bronze, .silver, .gold, .platinum, .diamond])
    }
}
