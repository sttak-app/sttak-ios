import SwiftUI

/// 차트 렌더링 추상화(확정 E10). View는 이 protocol에만 의존하고, 구체 구현(Swift Charts /
/// 추후 Canvas)은 교체 가능하다. 보이는 캔들 슬라이스를 받아 캔들스틱을 그린다.
@MainActor
protocol ChartRenderer {
    /// 보이는 캔들(윈도잉된 슬라이스) + 오버레이(지표·신호·하이라이트)를 렌더한 뷰.
    /// 렌더러는 "무엇을 그릴지"만 데이터로 받는다. 신호/마커 탭은 onSelectCandle로 전달.
    func candleChart(
        _ candles: [Candle],
        overlay: ChartOverlay,
        onSelectCandle: @escaping (Date) -> Void
    ) -> AnyView
}
