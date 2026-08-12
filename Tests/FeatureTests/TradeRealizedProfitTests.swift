import XCTest
@testable import sttak

/// 매도 실현손익 = (체결가 − 평단)·수량. 접수 모델에서 Mock은 즉시 체결하므로
/// 접수 결과 Trade(submittedTrade)의 realizedProfit로 검증한다. 체결가는 debugSetPrice로 주입.
@MainActor
final class TradeRealizedProfitTests: XCTestCase {

    private func makeSellViewModel(
        afterBuys buys: [(qty: Int, price: Int)],
        sellPrice: Int
    ) async throws -> (TradeViewModel, MockLocalStore) {
        let store = MockLocalStore(cash: 100_000_000)
        let repo = MockPortfolioRepository(store: store)
        let execute = ExecuteTrade(portfolio: repo)
        for buy in buys {
            await store.debugSetPrice(buy.price, for: "005930")
            _ = try await execute(type: .buy, stockCode: "005930", quantity: buy.qty, rationaleText: "매수")
        }
        let vm = TradeViewModel(
            type: .sell, stockCode: "005930", stockName: "삼성전자", price: .krw(sellPrice),
            executeTrade: execute, portfolio: repo, onCompleted: {}
        )
        await vm.load()
        await store.debugSetPrice(sellPrice, for: "005930")   // 매도 체결가
        return (vm, store)
    }

    func testRealizedProfit_partialSell() async throws {
        // 10@1000 + 10@1200 → 평단 1100. 1300원 5주 매도 → (1300−1100)·5 = +1000.
        let (vm, store) = try await makeSellViewModel(afterBuys: [(10, 1_000), (10, 1_200)], sellPrice: 1_300)
        vm.setQuantity(5)
        vm.rationaleText = "목표가 도달"
        await vm.execute()

        XCTAssertEqual(vm.submittedTrade?.realizedProfit?.amount, 1_000)
        let p = await store.portfolioSnapshot()
        XCTAssertEqual(p.holdings.first?.quantity, 15)
        XCTAssertEqual(p.holdings.first?.averagePrice.amount, 1_100)
    }

    func testRealizedLoss_sellBelowAverage() async throws {
        // 10@1300 → 평단 1300. 1100원 5주 매도 → (1100−1300)·5 = −1000.
        let (vm, _) = try await makeSellViewModel(afterBuys: [(10, 1_300)], sellPrice: 1_100)
        vm.setQuantity(5)
        vm.rationaleText = "흐름이 꺾여서"
        await vm.execute()
        XCTAssertEqual(vm.submittedTrade?.realizedProfit?.amount, -1_000)
    }

    func testRealizedProfit_fullSell() async throws {
        // 10@1000 → 평단 1000. 1500원 10주 전량 매도 → (1500−1000)·10 = +5000.
        let (vm, _) = try await makeSellViewModel(afterBuys: [(10, 1_000)], sellPrice: 1_500)
        vm.setQuantity(10)
        vm.rationaleText = "충분히 올라서"
        await vm.execute()
        XCTAssertEqual(vm.submittedTrade?.realizedProfit?.amount, 5_000)
    }
}
