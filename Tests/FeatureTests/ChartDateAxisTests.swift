import XCTest
@testable import sttak

/// 차트 x축 날짜 눈금·라벨 테스트.
/// 서버는 캔들 날짜를 UTC 시각으로 주므로, 기기 타임존과 무관하게 **KST 거래일**이 나와야 한다.
final class ChartDateAxisTests: XCTestCase {

    // MARK: KST 라벨

    /// UTC 자정 일봉(KST 09:00) → 같은 날짜로 읽힌다.
    func testDayLabel_utcMidnight_keepsSameCalendarDay() throws {
        XCTAssertEqual(Formatters.chartAxisDate(try iso("2026-09-19T00:00:00Z"), unit: .day), "9/19")
    }

    /// KST 자정을 UTC로 표현한 값(전날 15:00Z) → 하루 밀리지 않고 KST 날짜로 읽힌다.
    func testDayLabel_kstMidnightExpressedInUTC_doesNotShiftBackADay() throws {
        XCTAssertEqual(Formatters.chartAxisDate(try iso("2026-09-18T15:00:00Z"), unit: .day), "9/19")
    }

    /// 월·연 경계도 KST 기준으로 판정한다(UTC로는 아직 8월/2026년인 시각).
    func testMonthAndYearLabels_useKSTBoundaries() throws {
        XCTAssertEqual(Formatters.chartAxisDate(try iso("2026-08-31T15:00:00Z"), unit: .month), "9월")
        XCTAssertEqual(Formatters.chartAxisDate(try iso("2026-12-31T15:00:00Z"), unit: .year), "27년")
    }

    // MARK: 눈금 선택

    /// 한 달 이내 구간은 일 단위. 라벨은 겹치지 않을 개수만.
    func testMake_shortSpan_usesDayUnitWithoutOverlap() throws {
        let axis = ChartDateAxis.make(for: try candles(count: 22), plotWidth: plotWidth)
        XCTAssertEqual(axis.unit, .day)
        XCTAssertLessThanOrEqual(axis.tickIndices.count, Int(plotWidth / axis.labelPitch))
    }

    /// **가장 최근 봉에는 항상 라벨이 있어야 한다** — 사용자가 제일 먼저 찾는 날짜다.
    func testMake_alwaysLabelsMostRecentCandle() throws {
        for count in [1, 2, 6, 22, 66, 240, 365] {
            let axis = ChartDateAxis.make(for: try candles(count: count), plotWidth: plotWidth)
            XCTAssertEqual(axis.tickIndices.last, count - 1, "count=\(count): 최근 봉에 라벨 없음")
        }
    }

    /// 좁은 폭에서도 최근 봉 라벨은 살아남는다.
    func testMake_narrowPlot_stillLabelsMostRecentCandle() throws {
        for width in [60.0, 100.0, 160.0] as [CGFloat] {
            let axis = ChartDateAxis.make(for: try candles(count: 240), plotWidth: width)
            XCTAssertEqual(axis.tickIndices.last, 239, "width=\(width)")
        }
    }

    /// 봉이 적으면 모든 봉에 라벨(첫 봉 포함).
    func testMake_fewCandles_labelsEveryCandle() throws {
        let axis = ChartDateAxis.make(for: try candles(count: 6), plotWidth: plotWidth)
        XCTAssertEqual(axis.tickIndices, [0, 1, 2, 3, 4, 5])
    }

    /// 3개월 구간은 월 단위 + 월이 바뀌는 첫 봉에 라벨. 1/1 시작이면 2월 1일 = 인덱스 31.
    func testMake_threeMonthSpan_usesMonthBoundaries() throws {
        let axis = ChartDateAxis.make(for: try candles(count: 90), plotWidth: plotWidth)
        XCTAssertEqual(axis.unit, .month)
        XCTAssertTrue(axis.tickIndices.contains(31), "2월 경계 누락: \(axis.tickIndices)")
    }

    /// 라벨 폭은 그 단위의 최대 글자수("00/00")를 담을 수 있어야 한다.
    func testLabelWidth_fitsWidestLabelOfItsUnit() {
        XCTAssertGreaterThan(ChartDateAxis(tickIndices: [1], unit: .day).labelWidth, 30)
        XCTAssertGreaterThan(ChartDateAxis(tickIndices: [1], unit: .month).labelWidth, 24)
    }

    /// 이웃 눈금은 라벨이 겹치지 않을 만큼 떨어져 있어야 한다.
    func testMake_ticksNeverOverlap() throws {
        for count in [22, 66, 240, 365] {
            let axis = ChartDateAxis.make(for: try candles(count: count), plotWidth: plotWidth)
            let barWidth = plotWidth / CGFloat(count)
            for (previous, next) in zip(axis.tickIndices, axis.tickIndices.dropFirst()) {
                let gap = CGFloat(next - previous) * barWidth
                XCTAssertGreaterThanOrEqual(
                    gap, axis.labelWidth, "count=\(count): \(previous)↔\(next) 라벨 겹침"
                )
            }
        }
    }

    /// 눈금 인덱스는 중복 없이 오름차순.
    func testMake_tickIndicesAreUniqueAndSorted() throws {
        for count in 7...45 {
            let ticks = ChartDateAxis.make(for: try candles(count: count), plotWidth: plotWidth).tickIndices
            XCTAssertEqual(Set(ticks).count, ticks.count, "count=\(count)")
            XCTAssertEqual(ticks, ticks.sorted(), "count=\(count)")
        }
    }

    /// 모든 눈금은 실제 캔들 인덱스 범위 안에 있어야 한다(라벨 조회가 nil이 되지 않게).
    func testMake_tickIndicesStayInBounds() throws {
        for count in [1, 5, 22, 66, 240] {
            let list = try candles(count: count)
            for index in ChartDateAxis.make(for: list, plotWidth: plotWidth).tickIndices {
                XCTAssertTrue(list.indices.contains(index), "count=\(count), index=\(index)")
            }
        }
    }

    // MARK: 도메인 여유 — 양끝 라벨이 플롯을 벗어나지 않게

    /// 봉이 촘촘하면(라벨 절반 > 0.5봉) 도메인을 벌려야 한다.
    /// 벌린 뒤 봉이 다시 가늘어지는 되먹임까지 포함해 라벨 절반이 정확히 들어와야 한다.
    func testDomainInset_widensEnoughAfterBarsShrink() {
        let axis = ChartDateAxis(tickIndices: [0], unit: .day)
        for count in [22, 66, 240] {
            let inset = axis.domainInset(plotWidth: plotWidth, candleCount: count)
            XCTAssertGreaterThan(inset, 0, "count=\(count)")
            let barWidth = plotWidth / CGFloat(Double(count) + 2 * inset)
            let edgeRoom = CGFloat(0.5 + inset) * barWidth
            XCTAssertGreaterThanOrEqual(
                edgeRoom, axis.labelWidth / 2 - 0.01, "count=\(count): 양끝 라벨이 여전히 넘침"
            )
        }
    }

    /// 봉이 넓으면 기본 0.5봉 여백으로 충분하므로 더 벌리지 않는다.
    func testDomainInset_zeroWhenBarsAreWide() {
        let axis = ChartDateAxis(tickIndices: [0], unit: .day)
        XCTAssertEqual(axis.domainInset(plotWidth: plotWidth, candleCount: 6), 0)
    }

    func testMake_empty_returnsNoTicks() {
        XCTAssertEqual(ChartDateAxis.make(for: [], plotWidth: plotWidth), .empty)
    }

    func testMake_zeroWidth_returnsNoTicks() throws {
        XCTAssertEqual(ChartDateAxis.make(for: try candles(count: 22), plotWidth: 0), .empty)
    }

    // MARK: 헬퍼

    /// 아이폰 세로에서 캔들이 그려지는 대략 폭(차트 폭 − y축 가격 라벨).
    private let plotWidth: CGFloat = 308

    private func iso(_ raw: String) throws -> Date {
        try XCTUnwrap(JSONCoding.parseISO8601(raw), "ISO8601 파싱 실패: \(raw)")
    }

    /// 하루 간격 UTC 자정 캔들(주말 무시 — 눈금 로직은 달력 경계만 본다).
    private func candles(count: Int, from startISO: String = "2026-01-01T00:00:00Z") throws -> [Candle] {
        let base = try iso(startISO)
        return (0..<count).map { offset in
            Candle(
                date: base.addingTimeInterval(Double(offset) * 86_400),
                open: 100, high: 110, low: 90, close: 105, volume: 1_000
            )
        }
    }
}
