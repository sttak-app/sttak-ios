import SwiftUI
import Charts

/// ChartRenderer의 Swift Charts 구현. ⚠ 앱에서 `import Charts`는 이 파일 한 곳뿐(확정 E10).
/// 캔들 + 오버레이(지표 라인·밴드·지지저항·신호 구간/마커·선택)와 RSI/거래량 하위 패널을 그린다.
///
/// x축은 날짜가 아니라 **캔들 인덱스(0,1,2…)** 로 그린다. 주식 데이터는 주말·공휴일에 봉이 없어
/// 연속 Date 스케일로 그리면 봉 간격이 들쭉날쭉해지고 몸통 폭(.ratio)이 잘게 쪼개져 얇게 보인다.
/// 인덱스 스케일이면 간격이 균일해져 실제 증권 차트처럼 몸통이 통통하게 붙는다.
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

    /// 날짜 → 보이는 슬라이스 내 인덱스. 오버레이(지표·신호·선택)는 날짜로 오므로 인덱스로 되돌린다.
    private var indexByDate: [Date: Int] {
        Dictionary(candles.enumerated().map { ($1.date, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var body: some View {
        let indexByDate = self.indexByDate
        VStack(spacing: 6) {
            PriceChart(
                candles: candles, overlay: overlay, yDomain: yDomain,
                xDomain: xDomain, indexByDate: indexByDate, onSelectCandle: onSelectCandle
            )
            if !overlay.rsi.isEmpty {
                RSISubPanel(points: overlay.rsi, xDomain: xDomain, indexByDate: indexByDate)
                    .frame(height: 64)
            } else if overlay.showVolume {
                VolumeSubPanel(candles: candles, xDomain: xDomain)
                    .frame(height: 64)
            }
        }
    }

    /// 인덱스 x 도메인(양끝 봉이 잘리지 않게 ±0.5 여백).
    private var xDomain: ClosedRange<Double> {
        guard !candles.isEmpty else { return -0.5...0.5 }
        return -0.5...(Double(candles.count) - 0.5)
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
    let xDomain: ClosedRange<Double>
    let indexByDate: [Date: Int]
    let onSelectCandle: (Date) -> Void

    /// 오버레이 날짜를 인덱스로. 슬라이스 밖(regionEnd 등)이면 양끝으로 클램프.
    private func x(_ date: Date) -> Double? {
        indexByDate[date].map(Double.init)
    }
    private func xClamped(_ date: Date) -> Double {
        x(date) ?? (candles.isEmpty ? 0 : Double(candles.count - 1))
    }

    var body: some View {
        Chart {
            // 1) 신호 색칠 구간(배경) — 봉 전체를 덮게 시작 -0.5, 끝 +0.5.
            ForEach(overlay.signals) { signal in
                RectangleMark(
                    xStart: .value("시작", xClamped(signal.date) - 0.5),
                    xEnd: .value("끝", xClamped(signal.regionEnd) + 0.5),
                    yStart: .value("min", yDomain.lowerBound),
                    yEnd: .value("max", yDomain.upperBound)
                )
                .foregroundStyle(IndicatorCopy.directionColor(signal.direction).opacity(0.12))
            }

            // 2) 선택 봉 하이라이트
            if let selected = overlay.selectedDate, let sx = x(selected) {
                RuleMark(x: .value("선택", sx))
                    .foregroundStyle(AppColor.accent.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }

            // 3) 캔들 — 고가·저가는 얇은 심지(RuleMark), 시가·종가 사이는 통통한 몸통(RectangleMark).
            //    몸통 폭은 연속 x축에서 .ratio가 잘 안 잡혀 얇아지므로 xStart/xEnd(인덱스 ±0.35)로 명시.
            ForEach(Array(candles.enumerated()), id: \.offset) { index, candle in
                let color = candle.close >= candle.open ? AppColor.priceUp : AppColor.priceDown
                RuleMark(
                    x: .value("봉", Double(index)),
                    yStart: .value("저가", candle.low),
                    yEnd: .value("고가", candle.high)
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 1))

                RectangleMark(
                    xStart: .value("봉시작", Double(index) - 0.35),
                    xEnd: .value("봉끝", Double(index) + 0.35),
                    yStart: .value("시가", min(candle.open, candle.close)),
                    yEnd: .value("종가", max(candle.open, candle.close))
                )
                .foregroundStyle(color)
            }

            // 4) 볼린저 밴드(영역 + 라인)
            ForEach(overlay.bollinger) { point in
                if let px = x(point.date) {
                    AreaMark(
                        x: .value("봉", px),
                        yStart: .value("하단", point.lower),
                        yEnd: .value("상단", point.upper)
                    )
                    .foregroundStyle(AppColor.accent.opacity(0.07))
                }
            }
            ForEach(overlay.bollinger) { point in
                if let px = x(point.date) {
                    LineMark(x: .value("봉", px), y: .value("상단", point.upper), series: .value("s", "bb-up"))
                        .foregroundStyle(AppColor.accent)
                    LineMark(x: .value("봉", px), y: .value("하단", point.lower), series: .value("s", "bb-lo"))
                        .foregroundStyle(AppColor.accent)
                    LineMark(x: .value("봉", px), y: .value("중간", point.middle), series: .value("s", "bb-mid"))
                        .foregroundStyle(AppColor.indicatorMA)
                }
            }

            // 5) 이동평균선
            ForEach(overlay.movingAverages) { line in
                ForEach(line.points) { p in
                    if let px = x(p.date) {
                        LineMark(x: .value("봉", px), y: .value("값", p.value), series: .value("ma", line.period))
                            .foregroundStyle(line.color)
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                    }
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
                if let sx = x(signal.date) {
                    PointMark(x: .value("봉", sx), y: .value("고가", signal.high))
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
        }
        .chartYScale(domain: yDomain)
        .chartXScale(domain: xDomain)
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
                            if let raw: Double = proxy.value(atX: x) {
                                let index = Int(raw.rounded())
                                if candles.indices.contains(index) { onSelectCandle(candles[index].date) }
                            }
                        }
                    )
            }
        }
    }
}

// MARK: - RSI 하위 패널
private struct RSISubPanel: View {
    let points: [DatedValue]
    let xDomain: ClosedRange<Double>
    let indexByDate: [Date: Int]

    var body: some View {
        Chart {
            ForEach([30.0, 70.0], id: \.self) { level in
                RuleMark(y: .value("기준", level))
                    .foregroundStyle(AppColor.hairline)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            ForEach(points) { p in
                if let px = indexByDate[p.date].map(Double.init) {
                    LineMark(x: .value("봉", px), y: .value("RSI", p.value), series: .value("s", "rsi"))
                        .foregroundStyle(AppColor.indicatorRSI)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                }
            }
        }
        .chartYScale(domain: 0...100)
        .chartXScale(domain: xDomain)
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
    let xDomain: ClosedRange<Double>

    var body: some View {
        Chart {
            ForEach(Array(candles.enumerated()), id: \.offset) { index, candle in
                BarMark(
                    x: .value("봉", Double(index)),
                    y: .value("거래량", candle.volume),
                    width: .ratio(0.7)
                )
                .foregroundStyle((candle.close >= candle.open ? AppColor.priceUp : AppColor.priceDown).opacity(0.55))
            }
        }
        .chartXScale(domain: xDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}
