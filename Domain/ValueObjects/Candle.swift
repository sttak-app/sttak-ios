import Foundation

/// 캔들 한 개(OHLCV). 지표 계산(커밋 6)에 쓰이므로 가격은 Double(계산 친화).
struct Candle: Sendable, Equatable {
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int
}
