import Foundation

/// 보유 종목 한 줄의 현재가 기준 평가.
struct PositionValuation: Sendable, Equatable, Identifiable {
    let stockCode: String
    let stockName: String
    let quantity: Int
    let averagePrice: Money
    let currentPrice: Money
    let marketValue: Money      // 수량 × 현재가
    let unrealizedPnL: Money    // (현재가 − 평단) × 수량
    let returnRate: Double      // (현재가 − 평단) / 평단 × 100
    var id: String { stockCode }
}

/// 포트폴리오 전체 평가(현재가 기준). 수익률은 시작 자본(1천만) 대비.
struct PortfolioValuation: Sendable, Equatable {
    let cash: Money
    let stockValue: Money       // Σ 보유 평가금액
    let totalAssets: Money      // cash + stockValue
    let unrealizedPnL: Money    // Σ 보유 미실현손익
    let todaysPnL: Money        // Σ (현재가 − 전일종가) × 수량
    let totalReturn: Money      // totalAssets − 시작 자본
    let returnRate: Double      // totalReturn / 시작 자본 × 100
    let positions: [PositionValuation]

    /// 매수 가능 금액 = 보유 현금. (Mock은 결제 지연 없음 — 라벨만 다름)
    var buyingPower: Money { cash }
}
