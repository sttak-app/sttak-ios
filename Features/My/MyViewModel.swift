import SwiftUI

/// 마이페이지. 공유 store 기준 — 트레이드/퀴즈로 바뀐 현금·보유·기록이 그대로 반영된다.
@MainActor
@Observable
final class MyViewModel {
    enum Phase: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    enum TradeFilter: Equatable, CaseIterable {
        case all, buy, sell
        var label: String { self == .all ? "전체" : (self == .buy ? "매수" : "매도") }
    }

    private(set) var phase: Phase = .loading
    private(set) var valuation: PortfolioValuation?
    private(set) var trades: [Trade] = []   // 최신순
    var tradeFilter: TradeFilter = .all
    private(set) var openTradeIDs: Set<String> = []
    private(set) var openRetroIDs: Set<String> = []
    private(set) var namesByCode: [String: String] = [:]

    private let evaluate: EvaluatePortfolio
    private let portfolio: PortfolioRepository
    private let market: MarketDataRepository

    init(evaluate: EvaluatePortfolio, portfolio: PortfolioRepository, market: MarketDataRepository) {
        self.evaluate = evaluate
        self.portfolio = portfolio
        self.market = market
    }

    func name(for code: String) -> String { namesByCode[code] ?? code }

    var filteredTrades: [Trade] {
        switch tradeFilter {
        case .all: return trades
        case .buy: return trades.filter { $0.type == .buy }
        case .sell: return trades.filter { $0.type == .sell }
        }
    }

    /// 회고가 연결된 매도 건(최신순).
    var retroTrades: [Trade] {
        trades.filter { $0.type == .sell && $0.retrospective != nil }
    }

    func load() async {
        phase = .loading
        do {
            valuation = try await evaluate()
            let history = try await portfolio.fetchTrades()  // Repository가 최신순 보장
            trades = history
            let codes = Array(Set(history.map(\.stockCode)))
            if !codes.isEmpty {
                let stocks = try await market.fetchStocks(forCodes: codes)
                namesByCode = Dictionary(stocks.map { ($0.code, $0.name) }, uniquingKeysWith: { first, _ in first })
            }
            phase = .loaded
        } catch {
            phase = .failed("자산 정보를 불러오지 못했어요.")
        }
    }

    /// PENDING 주문 취소 후 목록 갱신.
    func cancelOrder(_ id: String) async {
        try? await portfolio.cancelOrder(id: id)
        await load()
    }

    func setFilter(_ filter: TradeFilter) { tradeFilter = filter }
    func toggleTrade(_ id: String) { toggle(id, in: &openTradeIDs) }
    func toggleRetro(_ id: String) { toggle(id, in: &openRetroIDs) }

    private func toggle(_ id: String, in set: inout Set<String>) {
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
    }
}
