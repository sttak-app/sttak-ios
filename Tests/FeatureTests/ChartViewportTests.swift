import XCTest
@testable import sttak

/// 차트 윈도잉(기간→보이는 범위, 줌·팬 클램프) 단위 테스트. 핸드오프 규칙 기준 손계산 앵커.
final class ChartViewportTests: XCTestCase {

    private let total = 240

    // MARK: 기간 → 보이는 캔들 범위 (periodMap, 최근 N봉)

    func testForPeriod_mapsToCandleCount_anchoredAtRecent() {
        XCTAssertEqual(ChartPeriod.day.candleCount, 6)
        XCTAssertEqual(ChartPeriod.week.candleCount, 12)
        XCTAssertEqual(ChartPeriod.month.candleCount, 22)
        XCTAssertEqual(ChartPeriod.threeMonths.candleCount, 66)
        XCTAssertEqual(ChartPeriod.year.candleCount, 240)

        let month = ChartViewport.forPeriod(.month, total: total)
        XCTAssertEqual(month.count, 22)
        XCTAssertEqual(month.start, 240 - 22) // 최근 22봉

        let year = ChartViewport.forPeriod(.year, total: total)
        XCTAssertEqual(year.count, 240)
        XCTAssertEqual(year.start, 0) // 전체
    }

    func testForPeriod_countClampedToTotal() {
        // 캔들이 10개뿐이면 1년(240)도 10으로.
        let vp = ChartViewport.forPeriod(.year, total: 10)
        XCTAssertEqual(vp.count, 10)
        XCTAssertEqual(vp.start, 0)
    }

    // MARK: 줌 (count×factor, 중앙 고정, 8..total 클램프)

    func testZoom_clampsCountAndKeepsCenter() {
        let vp = ChartViewport(start: 100, count: 40) // 중앙 = 120
        let zoomedIn = vp.zoomed(by: 0.5, total: total) // count → 20
        XCTAssertEqual(zoomedIn.count, 20)
        XCTAssertEqual(zoomedIn.start, 110) // 120 - 10, 중앙 유지
    }

    func testZoom_minCountFloor() {
        let vp = ChartViewport(start: 0, count: 12)
        let zoomed = vp.zoomed(by: 0.1, total: total) // 1.2 → floor 8
        XCTAssertEqual(zoomed.count, ChartViewport.minCount)
    }

    func testZoom_maxCountCeilingIsTotal() {
        let vp = ChartViewport(start: 100, count: 100)
        let zoomed = vp.zoomed(by: 10, total: total) // 1000 → total
        XCTAssertEqual(zoomed.count, total)
        XCTAssertEqual(zoomed.start, 0)
    }

    // MARK: 팬 (start 이동, 0..total-count 클램프)

    func testScroll_clampsStartWithinBounds() {
        let vp = ChartViewport(start: 200, count: 22) // maxStart = 218
        XCTAssertEqual(vp.scrolled(toStart: 230, total: total).start, 218) // 상한
        XCTAssertEqual(vp.scrolled(toStart: -5, total: total).start, 0)    // 하한
        XCTAssertEqual(vp.scrolled(toStart: 150, total: total).start, 150) // 범위 내
    }

    // MARK: 엣지

    func testEmpty_total() {
        let vp = ChartViewport.clamped(start: 0, count: 22, total: 0)
        XCTAssertEqual(vp.count, 0)
        XCTAssertEqual(vp.start, 0)
    }
}
