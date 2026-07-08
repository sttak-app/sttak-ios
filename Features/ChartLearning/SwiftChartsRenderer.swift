import SwiftUI
import Charts

/// ChartRenderer의 Swift Charts 구현. ⚠ 앱에서 `import Charts`는 이 파일 한 곳뿐(확정 E10).
/// 캔들 + 오버레이(지표 라인·밴드·지지저항·신호 구간/마커·선택)와 RSI/거래량 하위 패널을 그린다.
struct SwiftChartsRenderer: ChartRenderer {
    func candleChart(
        _ candles: [Candle],
        overlay: ChartOverlay,
        onSelectCandle: @escaping (Date) -> Void
    ) -> AnyView {
        AnyView(ChartStack(candles: candles, overlay: overlay, onSelectCandle: onSelectCandle))
    }
}

private struct ChartStack: View {
    let candles: [Candle]
    let overlay: ChartOverlay
    let onSelectCandle: (Date) -> Void

    var body: some View {
        VStack(spacing: 6) {
            PriceChart(candles: candles, overlay: overlay, yDomain: yDomain, onSelectCandle: onSelectCandle)
            if !overlay.rsi.isEmpty {
                RSISubPanel(points: overlay.rsi)
                    .frame(height: 64)
            } else if overlay.showVolume {
                VolumeSubPanel(candles: candles)
                    .frame(height: 64)
            }
        }
    }

    /// 가격 Y 범위(캔들 + 밴드 + 지지저항 포함, 약간 여백).
    private var yDomain: ClosedRange<Double> {
        var lo = candles.map(\.low).min() ?? 0
        var hi = candles.map(\.high).max() ?? 1
        for b in overlay.bollinger { lo = min(lo, b.lower); hi = max(hi, b.upper) }
        if let sr = overlay.supportResistance { lo = min(lo, sr.support); hi = max(hi, sr.resistance) }
        guard hi > lo else { return (lo - 1)...(hi + 1) }
        let pad = (hi - lo) * 0.08
        return (lo - pad)...(hi + pad)
    }
}

// MARK: - 가격 차트
private struct PriceChart: View {
    let candles: [Candle]
    let overlay: ChartOverlay
    let yDomain: ClosedRange<Double>
    let onSelectCandle: (Date) -> Void

    var body: some View {
        Chart {
            // 1) 신호 색칠 구간(배경)
            ForEach(overlay.signals) { signal in
                RectangleMark(
                    xStart: .value("시작", signal.date),
                    xEnd: .value("끝", signal.regionEnd),
                    yStart: .value("min", yDomain.lowerBound),
                    yEnd: .value("max", yDomain.upperBound)
                )
                .foregroundStyle(IndicatorCopy.directionColor(signal.direction).opacity(0.12))
            }

            // 2) 선택 봉 하이라이트
            if let selected = overlay.selectedDate {
                RuleMark(x: .value("선택", selected))
                    .foregroundStyle(AppColor.accent.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }

            // 3) 캔들
            ForEach(candles, id: \.date) { candle in
                let color = candle.close >= candle.open ? AppColor.priceUp : AppColor.priceDown
                RuleMark(
                    x: .value("날짜", candle.date),
                    yStart: .value("저가", candle.low),
                    yEnd: .value("고가", candle.high)
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 1))

                RectangleMark(
                    x: .value("날짜", candle.date),
                    yStart: .value("시가", min(candle.open, candle.close)),
                    yEnd: .value("종가", max(candle.open, candle.close)),
                    width: .ratio(0.6)
                )
                .foregroundStyle(color)
            }

            // 4) 볼린저 밴드(영역 + 라인)
            ForEach(overlay.bollinger) { point in
                AreaMark(
                    x: .value("날짜", point.date),
                    yStart: .value("하단", point.lower),
                    yEnd: .value("상단", point.upper)
                )
                .foregroundStyle(AppColor.accent.opacity(0.07))
            }
            ForEach(overlay.bollinger) { point in
                LineMark(x: .value("날짜", point.date), y: .value("상단", point.upper), series: .value("s", "bb-up"))
                    .foregroundStyle(AppColor.accent)
                LineMark(x: .value("날짜", point.date), y: .value("하단", point.lower), series: .value("s", "bb-lo"))
                    .foregroundStyle(AppColor.accent)
                LineMark(x: .value("날짜", point.date), y: .value("중간", point.middle), series: .value("s", "bb-mid"))
                    .foregroundStyle(AppColor.indicatorMA)
            }

            // 5) 이동평균선
            ForEach(overlay.movingAverages) { line in
                ForEach(line.points) { p in
                    LineMark(x: .value("날짜", p.date), y: .value("값", p.value), series: .value("ma", line.period))
                        .foregroundStyle(line.color)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                }
            }

            // 6) 지지·저항 수평선
            if let sr = overlay.supportResistance {
                RuleMark(y: .value("지지", sr.support))
                    .foregroundStyle(AppColor.indicatorSupportResist)
                    .lineStyle(StrokeStyle(lineWidth: 1.4, dash: [5, 4]))
                RuleMark(y: .value("저항", sr.resistance))
                    .foregroundStyle(AppColor.priceUp)
                    .lineStyle(StrokeStyle(lineWidth: 1.4, dash: [5, 4]))
            }

            // 7) 신호 번호 마커(위)
            ForEach(overlay.signals) { signal in
                PointMark(x: .value("날짜", signal.date), y: .value("고가", signal.high))
                    .symbolSize(0)
                    .annotation(position: .top, spacing: 2) {
                        Text("\(signal.id)")
                            .font(AppFont.microCaption)
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(AppColor.accent)
                            .clipShape(Circle())
                    }
            }
        }
        .chartYScale(domain: yDomain)
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
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture().onEnded { value in
                            guard let plotFrame = proxy.plotFrame else { return }
                            let x = value.location.x - geo[plotFrame].origin.x
                            if let date: Date = proxy.value(atX: x) { onSelectCandle(date) }
                        }
                    )
            }
        }
    }
}

// MARK: - RSI 하위 패널
private struct RSISubPanel: View {
    let points: [DatedValue]

    var body: some View {
        Chart {
            ForEach([30.0, 70.0], id: \.self) { level in
                RuleMark(y: .value("기준", level))
                    .foregroundStyle(AppColor.hairline)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            ForEach(points) { p in
                LineMark(x: .value("날짜", p.date), y: .value("RSI", p.value), series: .value("s", "rsi"))
                    .foregroundStyle(AppColor.indicatorRSI)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
        }
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: [30, 70]) { value in
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)").font(AppFont.microCaption).foregroundStyle(AppColor.textMuted2)
                    }
                }
            }
        }
    }
}

// MARK: - 거래량 하위 패널
private struct VolumeSubPanel: View {
    let candles: [Candle]

    var body: some View {
        Chart(candles, id: \.date) { candle in
            BarMark(
                x: .value("날짜", candle.date),
                y: .value("거래량", candle.volume),
                width: .ratio(0.6)
            )
            .foregroundStyle((candle.close >= candle.open ? AppColor.priceUp : AppColor.priceDown).opacity(0.55))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}
