import Foundation

/// 시세 스냅샷. 시간에 따라 변하므로 Stock과 분리한다.
/// (sttak-data.js: price, chg, spark[])
struct Quote: Sendable, Equatable {
    let price: Money            // 현재가
    let previousClose: Money    // 전일 종가 (오늘의 손익 기준)
    let changePercent: Double   // 등락률 % (chg)
    let sparkline: [Double]     // 미니 추세 (spark)

    /// DEBUG 시세 조정: 현재가에 오프셋(원)을 더한다. 전일 종가는 고정, 등락률은 재계산.
    func adjusted(byOffset offset: Int) -> Quote {
        let newPrice = max(1, price.amount + offset)
        let base = previousClose.amount
        let pct = base > 0 ? Double(newPrice - base) / Double(base) * 100 : changePercent
        return Quote(price: .krw(newPrice), previousClose: previousClose, changePercent: pct, sparkline: sparkline)
    }
}
