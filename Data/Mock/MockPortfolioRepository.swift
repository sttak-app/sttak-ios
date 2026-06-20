import Foundation

/// 포트폴리오 Mock. 매수/매도 시 공유 store의 cash·holdings를 실제로 갱신한다.
struct MockPortfolioRepository: PortfolioRepository {
    let store: MockLocalStore

    func fetchPortfolio() async throws -> Portfolio {
        await store.portfolioSnapshot()
    }

    func execute(
        type: TradeType,
        stockCode: String,
        quantity: Int,
        price: Money,
        rationale: TradeRationale
    ) async throws -> Trade {
        try await store.recordTrade(
            type: type, stockCode: stockCode, quantity: quantity, price: price, rationale: rationale
        )
    }

    func fetchTrades() async throws -> [Trade] {
        await store.allTrades()
    }

    func creditCash(_ amount: Money) async throws {
        await store.addCapital(amount.amount)
    }

    func attachRetrospective(_ retrospective: Retrospective, toTradeID id: String) async throws {
        await store.attachRetrospective(retrospective, toTradeID: id)
    }
}
