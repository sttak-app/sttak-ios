import Foundation

/// 차트 기간(표현 계층 윈도잉 — 커밋 8 결정). 캔들 수는 핸드오프 periodMap.
enum ChartPeriod: CaseIterable {
    case day, week, month, threeMonths, year

    var label: String {
        switch self {
        case .day: return "1일"
        case .week: return "1주"
        case .month: return "1개월"
        case .threeMonths: return "3개월"
        case .year: return "1년"
        }
    }

    /// 보이는 캔들 수.
    var candleCount: Int {
        switch self {
        case .day: return 6
        case .week: return 12
        case .month: return 22
        case .threeMonths: return 66
        case .year: return 240
        }
    }
}

/// 보이는 캔들 범위(윈도우). start = 시작 인덱스, count = 보이는 개수(줌 레벨).
/// 핸드오프 view={start,count} 모델. 순수 값 타입이라 단위 테스트 가능.
struct ChartViewport: Equatable {
    var start: Int
    var count: Int

    static let minCount = 8

    /// 범위를 유효하게 클램프. count ∈ [minCount, total], start ∈ [0, total-count].
    static func clamped(start: Int, count: Int, total: Int) -> ChartViewport {
        guard total > 0 else { return ChartViewport(start: 0, count: 0) }
        let c = max(min(minCount, total), min(count, total))
        let maxStart = max(0, total - c)
        let s = max(0, min(start, maxStart))
        return ChartViewport(start: s, count: c)
    }

    /// 기간 선택 → 최근 count봉.
    static func forPeriod(_ period: ChartPeriod, total: Int) -> ChartViewport {
        let c = min(period.candleCount, total)
        return clamped(start: total - c, count: c, total: total)
    }

    /// 줌 — count를 factor배(중앙 고정). factor<1 확대, >1 축소.
    func zoomed(by factor: Double, total: Int) -> ChartViewport {
        let newCount = Int((Double(count) * factor).rounded())
        return withCount(newCount, total: total)
    }

    /// 절대 count로 줌(현재 중앙 유지).
    func withCount(_ newCount: Int, total: Int) -> ChartViewport {
        let center = start + count / 2
        let newStart = center - newCount / 2
        return ChartViewport.clamped(start: newStart, count: newCount, total: total)
    }

    /// 팬 — start 이동.
    func scrolled(toStart newStart: Int, total: Int) -> ChartViewport {
        ChartViewport.clamped(start: newStart, count: count, total: total)
    }
}
