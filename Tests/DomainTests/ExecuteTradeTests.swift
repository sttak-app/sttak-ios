import XCTest
@testable import sttak

/// ExecuteTrade(검증) + Mock 정산 math(MockLocalStore.recordTrade) 테스트.
/// 접수 모델(ADR-011)에서 체결가는 클라이언트가 넘기지 않으므로, Mock 체결가는 debugSetPrice로 주입한다.
/// 기대값은 손계산 독립 앵커(자기참조 금지).
final class ExecuteTradeTests: XCTestCase {

    private func makeSystem(cash: Int = 1_000_000) -> (ExecuteTrade, MockPortfolioRepository, MockLocalStore) {
        let store = MockLocalStore(cash: cash)
        let repo = MockPortfolioRepository(store: store)
        return (ExecuteTrade(portfolio: repo), repo, store)
    }

    private func assertThrowsValidation(
        _ block: () async throws -> Void,
        file: StaticString = #file, line: UInt = #line
    ) async {
        do {
            try await block()
            XCTFail("validation 에러를 기대했지만 통과함", file: file, line: line)
        } catch let error as RepositoryError {
            guard case .validation = error else {
                return XCTFail("validation을 기대했지만 \(error)", file: file, line: line)
            }
        } catch {
            XCTFail("RepositoryError를 기대했지만 \(error)", file: file, line: line)
        }
    }

    // MARK: 근거/입력 검증

    func testRejectsEmptyRationale() async {
        let (execute, _, _) = makeSystem()
        await assertThrowsValidation {
            _ = try await execute(type: .buy, stockCode: "005930", quantity: 10, rationaleText: "   ")
        }
    }

    func testRejectsOver140CharRationale() async {
        let (execute, _, _) = makeSystem()
        let long = String(repeating: "가", count: TradeRationale.maxLength + 1) // 141자
        await assertThrowsValidation {
            _ = try await execute(type: .buy, stockCode: "005930", quantity: 10, rationaleText: long)
        }
    }

    func testRejectsZeroQuantity() async {
        let (execute, _, _) = makeSystem()
        await assertThrowsValidation {
            _ = try await execute(type: .buy, stockCode: "005930", quantity: 0, rationaleText: "근거")
        }
    }

    // MARK: 매수 — cash 감소, 보유 추가, 가중평균 평단

    func testBuy_reducesCash_addsHolding() async throws {
        let (execute, repo, store) = makeSystem(cash: 1_000_000)
        // 앵커: 1000원 10주 매수 → cash −10,000, 보유 10주 평단 1000
        await store.debugSetPrice(1_000, for: "005930")
        _ = try await execute(type: .buy, stockCode: "005930", quantity: 10, rationaleText: "근거")
        let p = try await repo.fetchPortfolio()
        XCTAssertEqual(p.cash.amount, 1_000_000 - 10_000)
        XCTAssertEqual(p.holdings.first?.quantity, 10)
        XCTAssertEqual(p.holdings.first?.averagePrice.amount, 1_000)
    }

    func testMultipleBuys_weightedAveragePrice() async throws {
        let (execute, repo, store) = makeSystem(cash: 1_000_000)
        // 앵커: 10@1000 + 10@1200 → 평단 (10·1000+10·1200)/20 = 22000/20 = 1100, 20주
        await store.debugSetPrice(1_000, for: "005930")
        _ = try await execute(type: .buy, stockCode: "005930", quantity: 10, rationaleText: "근거")
        await store.debugSetPrice(1_200, for: "005930")
        _ = try await execute(type: .buy, stockCode: "005930", quantity: 10, rationaleText: "근거")
        let p = try await repo.fetchPortfolio()
        XCTAssertEqual(p.holdings.first?.quantity, 20)
        XCTAssertEqual(p.holdings.first?.averagePrice.amount, 1_100)
        XCTAssertEqual(p.cash.amount, 1_000_000 - 10_000 - 12_000)
    }

    func testAveragePrice_truncatesFraction() async throws {
        let (execute, repo, store) = makeSystem(cash: 1_000_000)
        // 앵커: (10·1000+10·1233)/20 = 22330/20 = 1116.5 → 정수 나눗셈 절사 → 1116
        await store.debugSetPrice(1_000, for: "005930")
        _ = try await execute(type: .buy, stockCode: "005930", quantity: 10, rationaleText: "근거")
        await store.debugSetPrice(1_233, for: "005930")
        _ = try await execute(type: .buy, stockCode: "005930", quantity: 10, rationaleText: "근거")
        let p = try await repo.fetchPortfolio()
        XCTAssertEqual(p.holdings.first?.averagePrice.amount, 1_116) // 절사(버림)
    }

    // MARK: 매도 — cash 증가, 부분매도 평단 유지, 전량매도 제거

    func testPartialSell_increasesCash_keepsAveragePrice() async throws {
        let (execute, repo, store) = makeSystem(cash: 1_000_000)
        await store.debugSetPrice(1_000, for: "005930")
        _ = try await execute(type: .buy, stockCode: "005930", quantity: 10, rationaleText: "근거")
        await store.debugSetPrice(1_200, for: "005930")
        _ = try await execute(type: .buy, stockCode: "005930", quantity: 10, rationaleText: "근거") // 20@1100
        let cashBefore = try await repo.fetchPortfolio().cash.amount
        // 앵커: 1300원 5주 매도 → cash +6,500, 보유 15주 평단 1100 유지
        await store.debugSetPrice(1_300, for: "005930")
        _ = try await execute(type: .sell, stockCode: "005930", quantity: 5, rationaleText: "근거")
        let p = try await repo.fetchPortfolio()
        XCTAssertEqual(p.cash.amount, cashBefore + 6_500)
        XCTAssertEqual(p.holdings.first?.quantity, 15)
        XCTAssertEqual(p.holdings.first?.averagePrice.amount, 1_100) // 평단 유지
    }

    func testFullSell_removesHolding() async throws {
        let (execute, repo, store) = makeSystem(cash: 1_000_000)
        await store.debugSetPrice(1_000, for: "005930")
        _ = try await execute(type: .buy, stockCode: "005930", quantity: 10, rationaleText: "근거")
        await store.debugSetPrice(1_100, for: "005930")
        _ = try await execute(type: .sell, stockCode: "005930", quantity: 10, rationaleText: "근거")
        let p = try await repo.fetchPortfolio()
        XCTAssertTrue(p.holdings.isEmpty) // 전량 매도 → 보유 제거
    }

    // MARK: 잔고/보유 부족

    func testInsufficientCash_throwsValidation() async {
        let (execute, _, store) = makeSystem(cash: 5_000) // 1000*10 = 10,000 > 5,000
        await store.debugSetPrice(1_000, for: "005930")
        await assertThrowsValidation {
            _ = try await execute(type: .buy, stockCode: "005930", quantity: 10, rationaleText: "근거")
        }
    }

    func testInsufficientHolding_throwsValidation() async throws {
        let (execute, _, store) = makeSystem(cash: 1_000_000)
        await store.debugSetPrice(1_000, for: "005930")
        _ = try await execute(type: .buy, stockCode: "005930", quantity: 3, rationaleText: "근거")
        await assertThrowsValidation {
            _ = try await execute(type: .sell, stockCode: "005930", quantity: 5, rationaleText: "근거")
        }
    }
}
