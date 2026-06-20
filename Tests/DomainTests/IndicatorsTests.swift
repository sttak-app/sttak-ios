import XCTest
@testable import sttak

/// 지표 계산 단위 테스트.
/// 기대값은 구현 출력이 아니라 손계산/알려진 기준값으로 앵커링한다(자기참조 금지).
final class IndicatorsTests: XCTestCase {

    /// 종가 배열로 캔들 생성(지표는 close만 사용).
    private func makeCandles(_ closes: [Double]) -> [Candle] {
        closes.enumerated().map { index, close in
            Candle(
                date: Date(timeIntervalSince1970: TimeInterval(index) * 86_400),
                open: close, high: close, low: close, close: close, volume: 0
            )
        }
    }

    // MARK: SMA — 손계산

    func testSimpleMovingAverage_handComputed() {
        // closes [1,2,3,4,5], period 3 → [nil, nil, 2, 3, 4]
        let sma = Indicators.simpleMovingAverage(makeCandles([1, 2, 3, 4, 5]), period: 3)
        XCTAssertNil(sma[0]); XCTAssertNil(sma[1])
        XCTAssertEqual(sma[2]!, 2, accuracy: 1e-9)
        XCTAssertEqual(sma[3]!, 3, accuracy: 1e-9)
        XCTAssertEqual(sma[4]!, 4, accuracy: 1e-9)
    }

    // MARK: RSI — 소규모 손계산(period 3) + 알려진 경계(0/100)

    func testRSI_smallHandComputed() throws {
        // closes [10,11,10,11,12,11], period 3. 델타: +1,-1,+1,+1,-1
        // i=3 첫값: avgGain=2/3, avgLoss=1/3 → RS=2 → RSI=66.667
        // i=4: avgGain=(0.6667·2+1)/3, avgLoss=(0.3333·2)/3 → RS=3.5 → RSI=77.778
        // i=5: → RS≈1.0769 → RSI=51.852
        let rsi = Indicators.relativeStrengthIndex(makeCandles([10, 11, 10, 11, 12, 11]), period: 3)
        XCTAssertNil(rsi[0]); XCTAssertNil(rsi[1]); XCTAssertNil(rsi[2])
        XCTAssertEqual(try XCTUnwrap(rsi[3]), 66.6667, accuracy: 1e-3)
        XCTAssertEqual(try XCTUnwrap(rsi[4]), 77.7778, accuracy: 1e-3)
        XCTAssertEqual(try XCTUnwrap(rsi[5]), 51.8519, accuracy: 1e-3)
    }

    func testRSI_monotonicIncrease_approaches100() throws {
        // 순상승(손실 0) → RSI ≈ 100 (알려진 경계)
        let closes = (1...16).map(Double.init)
        let rsi = Indicators.relativeStrengthIndex(makeCandles(closes), period: 14)
        XCTAssertEqual(try XCTUnwrap(rsi[15]), 100, accuracy: 1e-3)
    }

    func testRSI_monotonicDecrease_approaches0() throws {
        // 순하락(이득 0) → RSI ≈ 0 (이 구현 경계)
        let closes = (1...16).map(Double.init).reversed().map { $0 }
        let rsi = Indicators.relativeStrengthIndex(makeCandles(closes), period: 14)
        XCTAssertEqual(try XCTUnwrap(rsi[15]), 0, accuracy: 1e-3)
    }

    // MARK: 볼린저 — 손계산(모표준편차)

    func testBollingerBands_handComputed() throws {
        // closes [2,4,6,8,10], period 5, k 2.
        // mean=6, 모분산=(16+4+0+4+16)/5=8, sd=√8=2.828427
        // upper=6+2·sd=11.656854, lower=6-2·sd=0.343146
        let bands = Indicators.bollingerBands(makeCandles([2, 4, 6, 8, 10]), period: 5, multiplier: 2)
        XCTAssertNil(bands.middle[3]); XCTAssertNil(bands.upper[3]); XCTAssertNil(bands.lower[3])
        XCTAssertEqual(try XCTUnwrap(bands.middle[4]), 6, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(bands.upper[4]), 11.656854, accuracy: 1e-4)
        XCTAssertEqual(try XCTUnwrap(bands.lower[4]), 0.343146, accuracy: 1e-4)
    }

    // MARK: 엣지 — 입력이 기간보다 짧을 때 / 빈 입력 (크래시 금지, 전부 nil)

    func testEdge_inputShorterThanPeriod_allNil() {
        let candles = makeCandles([1, 2, 3]) // 3개
        XCTAssertTrue(Indicators.simpleMovingAverage(candles, period: 5).allSatisfy { $0 == nil })
        XCTAssertTrue(Indicators.relativeStrengthIndex(candles, period: 14).allSatisfy { $0 == nil })
        let bands = Indicators.bollingerBands(candles, period: 20)
        XCTAssertTrue(bands.upper.allSatisfy { $0 == nil })
        XCTAssertTrue(bands.lower.allSatisfy { $0 == nil })
    }

    func testEdge_empty() {
        let empty: [Candle] = []
        XCTAssertTrue(Indicators.simpleMovingAverage(empty, period: 5).isEmpty)
        XCTAssertTrue(Indicators.relativeStrengthIndex(empty).isEmpty)
        XCTAssertTrue(Indicators.bollingerBands(empty).middle.isEmpty)
    }
}
