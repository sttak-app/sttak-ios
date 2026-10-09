import Foundation
import CoreGraphics

/// 캔들 인덱스 x축에 찍을 날짜 눈금 계산(순수 로직 — 테스트 대상).
///
/// 차트는 봉 간격을 균일하게 하려고 x를 **인덱스**로 그리므로(SwiftChartsRenderer 주석 참고),
/// 축도 "몇 번째 봉에 어떤 날짜를 쓸지"를 직접 골라야 한다. 몇 개를 찍을 수 있는지는 플롯 폭과
/// 라벨 폭으로 정해지므로 폭을 받아서 계산한다. 보이는 구간이 길어지면 일 단위 라벨은 겹치므로
/// 월·연 단위로 거칠어진다.
///
/// **가장 최근 봉은 항상 라벨을 갖는다** — 사용자가 제일 먼저 찾는 날짜이기 때문.
struct ChartDateAxis: Equatable {
    /// 라벨을 찍을 캔들 인덱스(오름차순).
    let tickIndices: [Int]
    /// 라벨 표기 단위.
    let unit: Formatters.ChartDateUnit

    /// 라벨 사이 최소 여백(pt). 이웃 라벨이 붙어 보이지 않을 만큼.
    static let minLabelSpacing: CGFloat = 8

    /// 양끝 라벨을 위한 안전 여백(pt). 플롯 폭은 y축 가격 라벨 폭(자릿수에 따라 변함)을 빼서
    /// 추정하므로 오차가 있다. 이 여백이 그 오차를 흡수해 끝 라벨이 잘리지 않게 한다.
    static let edgeSafetyMargin: CGFloat = 8

    static let empty = ChartDateAxis(tickIndices: [], unit: .day)

    /// 라벨 고정폭(pt). "00/00"처럼 그 단위의 최대 글자수를 담는 폭으로 잡는다.
    /// 폭이 고정돼야 글자수가 달라도(9/1 vs 12/31) 라벨 중심이 봉 중심에서 흔들리지 않는다.
    var labelWidth: CGFloat {
        switch unit {
        case .day: return 34    // "00/00"
        case .month, .year: return 28    // "00월" / "00년"
        }
    }

    /// 라벨 하나가 차지하는 최소 가로 공간(폭 + 여백).
    var labelPitch: CGFloat { labelWidth + Self.minLabelSpacing }

    /// 보이는 캔들 슬라이스 → 눈금. `plotWidth`는 캔들이 그려지는 영역의 가로 폭(y축 라벨 제외).
    static func make(for candles: [Candle], plotWidth: CGFloat) -> ChartDateAxis {
        guard let first = candles.first, let last = candles.last, plotWidth > 0 else { return .empty }
        let spanDays = last.date.timeIntervalSince(first.date) / 86_400

        // 한 달 남짓까지는 날짜(9/19)가 유용하고, 그보다 길면 월 라벨이 겹치지 않고 읽힌다.
        let unit: Formatters.ChartDateUnit
        if spanDays <= 35 {
            unit = .day
        } else {
            unit = spanDays <= 400 ? .month : .year
        }

        let pitch = ChartDateAxis(tickIndices: [], unit: unit).labelPitch
        let maxCount = max(1, Int(plotWidth / pitch))
        // 라벨이 겹치지 않기 위해 이웃 눈금이 떨어져 있어야 하는 봉 수.
        let barWidth = plotWidth / CGFloat(candles.count)
        let minBarGap = barWidth > 0 ? max(1, Int((pitch / barWidth).rounded(.up))) : 1

        let indices: [Int]
        switch unit {
        case .day:
            indices = evenlySpaced(count: candles.count, limit: maxCount)
        case .month, .year:
            indices = pickBoundaries(
                of: candles, unit: unit, minBarGap: minBarGap, limit: maxCount
            )
        }
        return ChartDateAxis(tickIndices: indices, unit: unit)
    }

    /// 양끝 봉 라벨이 플롯을 벗어나지 않도록 x 도메인 양쪽에 더해야 할 여유(봉 단위).
    ///
    /// 기본 도메인이 이미 양쪽에 0.5봉을 두므로 라벨 절반이 그보다 넓을 때만 벌린다. 단,
    /// 여유를 더하면 도메인이 넓어져 봉이 다시 가늘어지므로 그 되먹임을 포함해 풀어야 한다.
    /// 봉폭 = plotWidth / (count + 2·inset) 일 때 `(0.5 + inset)·봉폭 ≥ labelWidth/2` 를 만족하는 최소 inset:
    ///
    ///     inset = (labelWidth/2 · count − plotWidth/2) / (plotWidth − labelWidth)
    func domainInset(plotWidth: CGFloat, candleCount: Int) -> Double {
        guard candleCount > 0, plotWidth > 0 else { return 0 }
        let needed = labelWidth + Self.edgeSafetyMargin
        // 플롯이 라벨 하나도 못 담을 만큼 좁으면 벌려도 소용없다(그 경우 라벨이 잘리는 편을 택한다).
        let denominator = plotWidth - needed
        guard denominator > 0 else { return 0 }
        let numerator = needed / 2 * CGFloat(candleCount) - plotWidth / 2
        return Double(max(0, numerator / denominator))
    }

    // MARK: 눈금 선택

    /// 0..<count 에서 양끝(첫·마지막 봉)을 포함해 최대 limit개를 균등하게 고른다.
    private static func evenlySpaced(count: Int, limit: Int) -> [Int] {
        guard count > 0 else { return [] }
        let slots = min(limit, count)
        // 하나만 들어간다면 가장 최근 봉을 택한다.
        guard slots > 1 else { return [count - 1] }
        guard count > slots else { return Array(0..<count) }
        let step = Double(count - 1) / Double(slots - 1)
        var seen = Set<Int>()
        return (0..<slots).compactMap { position in
            let index = Int((Double(position) * step).rounded())
            return seen.insert(index).inserted ? index : nil
        }
    }

    /// 월·연 경계 봉을 최소 간격을 지키며 고르고, 마지막 봉을 반드시 포함한다.
    private static func pickBoundaries(
        of candles: [Candle], unit: Formatters.ChartDateUnit, minBarGap: Int, limit: Int
    ) -> [Int] {
        var picked: [Int] = []
        for index in boundaries(of: candles, unit: unit) {
            if let previous = picked.last, index - previous < minBarGap { continue }
            picked.append(index)
        }

        // 최근 봉 날짜는 항상 보이게. 직전 라벨과 너무 가까우면 그 라벨을 밀어내고 자리를 내준다.
        let lastIndex = candles.count - 1
        if picked.last != lastIndex {
            while let previous = picked.last, lastIndex - previous < minBarGap {
                picked.removeLast()
            }
            picked.append(lastIndex)
        }
        // 폭이 아주 좁아 limit을 넘길 때는 최근 쪽을 남긴다.
        return picked.count > limit ? Array(picked.suffix(limit)) : picked
    }

    /// 월·연이 바뀌는 첫 봉의 인덱스(KST 기준). 증권사 차트처럼 경계에 라벨이 온다.
    private static func boundaries(of candles: [Candle], unit: Formatters.ChartDateUnit) -> [Int] {
        let calendar = Formatters.koreaCalendar
        let component: Calendar.Component = unit == .year ? .year : .month
        var result: [Int] = []
        var previous: Int?
        for (index, candle) in candles.enumerated() {
            let value = calendar.component(component, from: candle.date)
            if value != previous {
                result.append(index)
                previous = value
            }
        }
        return result
    }
}
