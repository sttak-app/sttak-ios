import SwiftUI

/// 차트 렌더링 추상화(확정 E10). View는 이 protocol에만 의존하고, 구체 구현(Swift Charts /
/// 추후 Canvas)은 교체 가능하다. 보이는 캔들 슬라이스를 받아 캔들스틱을 그린다.
@MainActor
protocol ChartRenderer {
    /// 보이는 캔들(이미 윈도잉된 슬라이스)을 캔들스틱으로 렌더한 뷰.
    func candleChart(_ candles: [Candle]) -> AnyView
}
