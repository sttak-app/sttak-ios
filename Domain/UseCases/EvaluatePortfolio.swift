import Foundation

/// 포트폴리오 평가(현재가 기준). 총 평가 자산 = cash + Σ(수량×현재가),
/// 미실현손익 = Σ((현재가−평단)×수량), 수익률 = (총자산−시작자본)/시작자본×100.
/// 핵심 계산은 순수 함수(`evaluate`)로 분리 — 현재가·이름을 주입해 결정적으로 테스트한다.
struct EvaluatePortfolio: Sendable {
    let portfolio: PortfolioRepository
    let market: MarketDataRepository

    /// 모든 사용자의 시작 자본(수익률 기준). 핸드오프: "시작 자산 10,000,000원 대비".
    static let startingCapital = 10_000_000

    func callAsFunction() async throws -> PortfolioValuation {
        let snapshot = try await portfolio.fetchPortfolio()
        let codes = snapshot.holdings.map(\.stockCode)

        let quotes = codes.isEmpty ? [:] : try await market.fetchQuotes(forStockCodes: codes)
        let stocks = codes.isEmpty ? [] : try await market.fetchStocks(forCodes: codes)
        let prices = quotes.mapValues(\.price)
        let previousCloses = quotes.mapValues(\.previousClose)
        let names = Dictionary(stocks.map { ($0.code, $0.name) }, uniquingKeysWith: { first, _ in first })

        return Self.evaluate(
            portfolio: snapshot, prices: prices, previousCloses: previousCloses,
            names: names, startingCapital: Self.startingCapital
        )
    }

    /// 순수 평가(현재가·전일종가·이름 주입). 가격 없는 보유는 평가에서 제외.
    static func evaluate(
        portfolio: Portfolio,
        prices: [String: Money],
        previousCloses: [String: Money] = [:],
        names: [String: String],
        startingCapital: Int
    ) -> PortfolioValuation {
        let positions: [PositionValuation] = portfolio.holdings.compactMap { holding in
            guard let price = prices[holding.stockCode] else { return nil }
            let quantity = holding.quantity
            let avg = holding.averagePrice.amount
            let pnl = (price.amount - avg) * quantity
            let rate = avg > 0 ? Double(price.amount - avg) / Double(avg) * 100 : 0
            return PositionValuation(
                stockCode: holding.stockCode,
                stockName: names[holding.stockCode] ?? holding.stockCode,
                quantity: quantity,
                averagePrice: holding.averagePrice,
                currentPrice: price,
                marketValue: .krw(price.amount * quantity),
                unrealizedPnL: .krw(pnl),
                returnRate: rate
            )
        }

        let stockValue = positions.reduce(0) { $0 + $1.marketValue.amount }
        let unrealized = positions.reduce(0) { $0 + $1.unrealizedPnL.amount }
        // 오늘의 손익 = Σ (현재가 − 전일종가) × 수량. 전일종가 없으면 0(변동 없음으로 간주).
        let todays = portfolio.holdings.reduce(0) { sum, holding in
            guard let price = prices[holding.stockCode], let prev = previousCloses[holding.stockCode] else { return sum }
            return sum + (price.amount - prev.amount) * holding.quantity
        }
        let total = portfolio.cash.amount + stockValue
        let totalReturn = total - startingCapital
        let rate = startingCapital > 0 ? Double(totalReturn) / Double(startingCapital) * 100 : 0

        return PortfolioValuation(
            cash: portfolio.cash,
            stockValue: .krw(stockValue),
            totalAssets: .krw(total),
            unrealizedPnL: .krw(unrealized),
            todaysPnL: .krw(todays),
            totalReturn: .krw(totalReturn),
            returnRate: rate,
            positions: positions
        )
    }
}
