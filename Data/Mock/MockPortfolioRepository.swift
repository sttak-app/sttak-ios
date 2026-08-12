import Foundation

/// 포트폴리오 Mock. 프리뷰/테스트/데모용 — 접수 즉시 FILLED로 정산(공유 store의 cash·holdings 갱신).
/// PENDING/거부/취소 라이프사이클은 Live에서만 재현한다.
struct MockPortfolioRepository: PortfolioRepository {
    let store: MockLocalStore

    func fetchPortfolio() async throws -> Portfolio {
        await store.portfolioSnapshot()
    }

    func placeOrder(
        type: TradeType,
        stockCode: String,
        quantity: Int,
        rationale: TradeRationale
    ) async throws -> Trade {
        // 체결가는 시세 레이어(store)에서 내부 조회 — 클라이언트 price 입력이 사라졌으므로.
        try await store.recordTrade(type: type, stockCode: stockCode, quantity: quantity, rationale: rationale)
    }

    func fetchTrades() async throws -> [Trade] {
        await store.allTrades()
    }

    func cancelOrder(id: String) async throws {
        // Mock은 즉시 FILLED라 취소할 PENDING이 없음 → no-op(UI에서 취소 버튼은 PENDING만 노출).
    }

    func fetchReasonTemplates(type: TradeType) async throws -> [String] {
        type == .buy ? MockData.buyReasonTemplates : MockData.sellReasonTemplates
    }

    func creditCash(_ amount: Money) async throws {
        await store.addCapital(amount.amount)
    }
}
