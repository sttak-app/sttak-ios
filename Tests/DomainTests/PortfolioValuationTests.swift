import XCTest
@testable import sttak

/// 포트폴리오 평가(순수 함수). 현재가·이름 주입으로 결정적. 손계산 독립 앵커(자기참조 금지).
final class PortfolioValuationTests: XCTestCase {

    func testValuation_singlePosition_anchor() {
        // 앵커: cash 11,500,000 + 10주(평단 1100, 현재가 1300)
        // 평가자산 = 11,500,000 + 10×1300 = 11,513,000, 미실현 = (1300−1100)×10 = +2,000
        let portfolio = Portfolio(cash: .krw(11_500_000), holdings: [
            Holding(stockCode: "X", quantity: 10, averagePrice: .krw(1_100)),
        ])
        let v = EvaluatePortfolio.evaluate(
            portfolio: portfolio, prices: ["X": .krw(1_300)], names: ["X": "테스트"], startingCapital: 10_000_000
        )
        XCTAssertEqual(v.stockValue.amount, 13_000)
        XCTAssertEqual(v.totalAssets.amount, 11_513_000)
        XCTAssertEqual(v.unrealizedPnL.amount, 2_000)
        XCTAssertEqual(v.totalReturn.amount, 1_513_000)       // 11,513,000 − 10,000,000
        XCTAssertEqual(v.returnRate, 15.13, accuracy: 0.0001) // 1,513,000 / 10,000,000 × 100
        XCTAssertEqual(v.positions.first?.stockName, "테스트")
        XCTAssertEqual(v.positions.first?.marketValue.amount, 13_000)
        XCTAssertEqual(v.positions.first?.returnRate ?? 0, 200.0 / 1_100.0 * 100, accuracy: 0.0001)
    }

    func testValuation_todaysPnL_usesPreviousClose() {
        // 현재가 1300·전일종가 1250·10주 → 오늘의 손익 = (1300−1250)×10 = +500.
        // (미실현은 평단 1100 기준 +2,000과 별개)
        let portfolio = Portfolio(cash: .krw(1_000_000), holdings: [
            Holding(stockCode: "X", quantity: 10, averagePrice: .krw(1_100)),
        ])
        let v = EvaluatePortfolio.evaluate(
            portfolio: portfolio, prices: ["X": .krw(1_300)], previousCloses: ["X": .krw(1_250)],
            names: [:], startingCapital: 10_000_000
        )
        XCTAssertEqual(v.todaysPnL.amount, 500)
        XCTAssertEqual(v.unrealizedPnL.amount, 2_000)
    }

    func testValuation_todaysPnL_zeroWithoutPreviousClose() {
        let portfolio = Portfolio(cash: .krw(1_000_000), holdings: [
            Holding(stockCode: "X", quantity: 10, averagePrice: .krw(1_100)),
        ])
        let v = EvaluatePortfolio.evaluate(
            portfolio: portfolio, prices: ["X": .krw(1_300)], names: [:], startingCapital: 10_000_000
        )
        XCTAssertEqual(v.todaysPnL.amount, 0) // 전일종가 없으면 0
    }

    func testValuation_multiPosition_sumsAndLoss() {
        // 삼성 10@67,800 → 73,400, SK 3@195,000 → 198,500. cash 8,738,000.
        // stockValue = 10×73,400 + 3×198,500 = 734,000 + 595,500 = 1,329,500
        // total = 8,738,000 + 1,329,500 = 10,067,500
        // 미실현 = (73,400−67,800)×10 + (198,500−195,000)×3 = 56,000 + 10,500 = 66,500
        let portfolio = Portfolio(cash: .krw(8_738_000), holdings: [
            Holding(stockCode: "005930", quantity: 10, averagePrice: .krw(67_800)),
            Holding(stockCode: "000660", quantity: 3, averagePrice: .krw(195_000)),
        ])
        let v = EvaluatePortfolio.evaluate(
            portfolio: portfolio,
            prices: ["005930": .krw(73_400), "000660": .krw(198_500)],
            names: ["005930": "삼성전자", "000660": "SK하이닉스"],
            startingCapital: 10_000_000
        )
        XCTAssertEqual(v.stockValue.amount, 1_329_500)
        XCTAssertEqual(v.totalAssets.amount, 10_067_500)
        XCTAssertEqual(v.unrealizedPnL.amount, 66_500)
        XCTAssertEqual(v.totalReturn.amount, 67_500)
        XCTAssertEqual(v.returnRate, 0.675, accuracy: 0.0001)
        XCTAssertEqual(v.positions.count, 2)
    }

    func testValuation_lossBelowStart() {
        // cash 9,000,000 + 5주(평단 80,000, 현재가 70,000) → 평가 350,000, total 9,350,000(시작 미만)
        let portfolio = Portfolio(cash: .krw(9_000_000), holdings: [
            Holding(stockCode: "A", quantity: 5, averagePrice: .krw(80_000)),
        ])
        let v = EvaluatePortfolio.evaluate(
            portfolio: portfolio, prices: ["A": .krw(70_000)], names: [:], startingCapital: 10_000_000
        )
        XCTAssertEqual(v.totalAssets.amount, 9_350_000)
        XCTAssertEqual(v.unrealizedPnL.amount, -50_000)       // (70,000−80,000)×5
        XCTAssertEqual(v.totalReturn.amount, -650_000)
        XCTAssertEqual(v.returnRate, -6.5, accuracy: 0.0001)
        XCTAssertEqual(v.positions.first?.stockName, "A")     // 이름 없으면 코드로 폴백
    }

    func testValuation_noHoldings_allCash() {
        let portfolio = Portfolio(cash: .krw(10_000_000), holdings: [])
        let v = EvaluatePortfolio.evaluate(portfolio: portfolio, prices: [:], names: [:], startingCapital: 10_000_000)
        XCTAssertEqual(v.stockValue.amount, 0)
        XCTAssertEqual(v.totalAssets.amount, 10_000_000)
        XCTAssertEqual(v.unrealizedPnL.amount, 0)
        XCTAssertEqual(v.totalReturn.amount, 0)
        XCTAssertEqual(v.returnRate, 0, accuracy: 0.0001)
        XCTAssertTrue(v.positions.isEmpty)
    }

    func testValuation_excludesPricelessHolding() {
        // 가격 없는 보유는 평가에서 제외(현재가 미수신 방어).
        let portfolio = Portfolio(cash: .krw(10_000_000), holdings: [
            Holding(stockCode: "WITH", quantity: 2, averagePrice: .krw(1_000)),
            Holding(stockCode: "NOPRICE", quantity: 5, averagePrice: .krw(1_000)),
        ])
        let v = EvaluatePortfolio.evaluate(
            portfolio: portfolio, prices: ["WITH": .krw(1_500)], names: [:], startingCapital: 10_000_000
        )
        XCTAssertEqual(v.positions.count, 1)
        XCTAssertEqual(v.stockValue.amount, 3_000)            // 2×1,500 (NOPRICE 제외)
    }
}
