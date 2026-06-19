import Foundation

/// 시세 스냅샷. 시간에 따라 변하므로 Stock과 분리한다.
/// (sttak-data.js: price, chg, spark[])
struct Quote: Sendable, Equatable {
    let price: Money            // 현재가
    let changePercent: Double   // 등락률 % (chg)
    let sparkline: [Double]     // 미니 추세 (spark)
}
