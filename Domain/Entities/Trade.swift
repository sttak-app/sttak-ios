import Foundation

/// 매매 종류.
enum TradeType: Sendable, Equatable {
    case buy   // 매수
    case sell  // 매도
}

/// 매수/매도 한 건. 매도 건에는 회고가 연결된다. (sttak_trades 구조와 교차검증)
struct Trade: Sendable, Equatable, Identifiable {
    let id: String
    let type: TradeType
    let stockCode: String
    let quantity: Int
    let price: Money                   // 체결가(주당)
    let rationale: TradeRationale      // 근거(필수)
    let executedAt: Date
    let realizedProfit: Money?         // 매도 실현손익 (매수는 nil) = (매도가 − 평단) × 수량
    let retrospective: Retrospective?  // 매도 건에 연결 (매수는 nil)
}
