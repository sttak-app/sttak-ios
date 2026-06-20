import SwiftUI
import Charts

/// ChartRenderer의 Swift Charts 구현. ⚠ 앱에서 `import Charts`는 이 파일 한 곳뿐 —
/// 추후 Canvas 렌더러로 교체 시 이 파일만 바꾸면 된다(확정 E10).
struct SwiftChartsRenderer: ChartRenderer {
    func candleChart(_ candles: [Candle]) -> AnyView {
        AnyView(CandleStickChart(candles: candles))
    }
}

private struct CandleStickChart: View {
    let candles: [Candle]

    var body: some View {
        Chart(candles, id: \.date) { candle in
            // 한국 증시 관례: 상승(close≥open) 빨강, 하락 파랑 (서구식 초록 미사용).
            let color = candle.close >= candle.open ? AppColor.priceUp : AppColor.priceDown

            // 꼬리(고가~저가)
            RuleMark(
                x: .value("날짜", candle.date),
                yStart: .value("저가", candle.low),
                yEnd: .value("고가", candle.high)
            )
            .foregroundStyle(color)
            .lineStyle(StrokeStyle(lineWidth: 1))

            // 몸통(시가~종가)
            RectangleMark(
                x: .value("날짜", candle.date),
                yStart: .value("시가", min(candle.open, candle.close)),
                yEnd: .value("종가", max(candle.open, candle.close)),
                width: .ratio(0.6)
            )
            .foregroundStyle(color)
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine().foregroundStyle(AppColor.hairline2)
                AxisValueLabel {
                    if let price = value.as(Double.self) {
                        Text(Formatters.grouped(Int(price)))
                            .font(AppFont.microCaption)
                            .foregroundStyle(AppColor.textMuted2)
                    }
                }
            }
        }
        .chartYScale(domain: yDomain)
    }

    /// 보이는 캔들의 최저/최고에 약간의 여백.
    private var yDomain: ClosedRange<Double> {
        let lows = candles.map(\.low)
        let highs = candles.map(\.high)
        guard let lo = lows.min(), let hi = highs.max(), hi > lo else { return 0...1 }
        let padding = (hi - lo) * 0.08
        return (lo - padding)...(hi + padding)
    }
}
