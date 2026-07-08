import XCTest
@testable import sttak

/// Mock 회고의 실현 손익 분기(win/loss) + 부분매도 + 스트리밍 완성 검증.
final class MockRetrospectiveTests: XCTestCase {

    private func sellTrade() -> Trade {
        Trade(
            id: "t1", type: .sell, stockCode: "005930", quantity: 5, price: .krw(72_000),
            rationale: TradeRationale(text: "목표가 도달"), executedAt: Date(timeIntervalSince1970: 0),
            realizedProfit: .krw(20_000), retrospective: nil
        )
    }

    private func finalRetro(profit: Money, partial: Bool) async throws -> Retrospective {
        let repo = MockRetrospectiveRepository(stepDelay: .zero)
        let stream = repo.generateRetrospective(for: sellTrade(), realizedProfit: profit, isPartialSell: partial)
        var last: Retrospective?
        for try await snapshot in stream { last = snapshot }
        return try XCTUnwrap(last)
    }

    func testProfit_usesWinTemplate() async throws {
        let retro = try await finalRetro(profit: .krw(150_000), partial: false)
        XCTAssertEqual(retro.goodPoints.count, 2)
        XCTAssertTrue(retro.goodPoints[1].contains("수익을 실현"))
        XCTAssertFalse(retro.isPartialSell)
    }

    func testLoss_usesLossTemplate() async throws {
        let retro = try await finalRetro(profit: .krw(-80_000), partial: false)
        XCTAssertTrue(retro.goodPoints[1].contains("손실을 키우지 않고"))
    }

    func testPartialSell_addsPartialWatchPoint() async throws {
        let retro = try await finalRetro(profit: .krw(0), partial: true)
        XCTAssertTrue(retro.isPartialSell)
        XCTAssertTrue(retro.watchPoints.first?.contains("일부만 매도") ?? false)
        XCTAssertEqual(retro.watchPoints.count, 3) // 부분 + 기본 2
    }

    func testStreaming_accumulatesToComplete() async throws {
        let repo = MockRetrospectiveRepository(stepDelay: .zero)
        let stream = repo.generateRetrospective(for: sellTrade(), realizedProfit: .krw(10_000), isPartialSell: false)
        var snapshots: [Retrospective] = []
        for try await s in stream { snapshots.append(s) }
        XCTAssertEqual(snapshots.first?.goodPoints.isEmpty, true)  // 첫 스냅샷은 비어 점진
        XCTAssertEqual(snapshots.last?.goodPoints.count, 2)        // 완성본
        XCTAssertEqual(snapshots.last?.watchPoints.count, 2)
    }
}
