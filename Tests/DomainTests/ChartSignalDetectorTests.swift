import XCTest
@testable import sttak

/// 신호 탐지 단위 테스트. 각 신호가 "실제로 일어나도록" 구성한 입력으로 검증한다.
/// 크로스/볼린저는 손추론으로 발생 인덱스까지 앵커링하고, RSI 크로싱은 경계 통과 존재로 앵커링한다.
final class ChartSignalDetectorTests: XCTestCase {

    private func makeCandles(_ closes: [Double]) -> [Candle] {
        closes.enumerated().map { index, close in
            Candle(
                date: Date(timeIntervalSince1970: TimeInterval(index) * 86_400),
                open: close, high: close, low: close, close: close, volume: 0
            )
        }
    }

    // MARK: 골든/데드크로스 (MA5 × MA20)

    func testGoldenCross_detectedAtCrossIndex() {
        // 0..19 평탄(100) → MA5=MA20=100. 20부터 급등 → MA5가 MA20 상향 돌파(i=20).
        let closes = Array(repeating: 100.0, count: 20) + [110, 120, 130, 140, 150, 160, 170, 180]
        let golden = ChartSignalDetector.detect(makeCandles(closes)).filter { $0.kind == .goldenCross }
        XCTAssertEqual(golden.count, 1)
        XCTAssertEqual(golden.first?.candleIndex, 20)
        XCTAssertEqual(golden.first?.subsequentDirection, .up)
    }

    func testDeadCross_detectedAtCrossIndex() {
        // 0..19 평탄 → 20부터 급락 → MA5가 MA20 하향 돌파(i=20).
        let closes = Array(repeating: 100.0, count: 20) + [90, 80, 70, 60, 50, 40, 30, 20]
        let dead = ChartSignalDetector.detect(makeCandles(closes)).filter { $0.kind == .deadCross }
        XCTAssertEqual(dead.count, 1)
        XCTAssertEqual(dead.first?.candleIndex, 20)
        XCTAssertEqual(dead.first?.subsequentDirection, .down)
    }

    // MARK: RSI 과열/과매도 (70 상향·30 하향 돌파)

    func testRSIOverbought_crossingDetected() {
        // 하락(RSI≈0)에서 강한 상승 랠리로 RSI가 70을 상향 돌파.
        let decline = (0..<15).map { 100.0 - Double($0) * 2 } // 100..72
        let rally = [80.0, 90, 102, 116, 132, 150, 170, 192, 216, 242, 270]
        let signals = ChartSignalDetector.detect(makeCandles(decline + rally))
        XCTAssertTrue(signals.contains { $0.kind == .rsiOverbought })
    }

    func testRSIOversold_crossingDetected() {
        // 상승(RSI≈100)에서 강한 하락으로 RSI가 30을 하향 돌파.
        let rise = (0..<15).map { 72.0 + Double($0) * 2 } // 72..100
        let fall = [92.0, 82, 70, 56, 40, 24, 12, 6, 3, 2, 1]
        let signals = ChartSignalDetector.detect(makeCandles(rise + fall))
        XCTAssertTrue(signals.contains { $0.kind == .rsiOversold })
    }

    // MARK: 볼린저 상·하단 터치

    func testBollingerUpperTouch_detected() {
        // 좁은 진동(98/102) → 위로 스파이크(130) → 상단 띠 터치.
        let closes = (0..<20).map { $0 % 2 == 0 ? 98.0 : 102.0 } + [130, 130, 130, 130]
        let signals = ChartSignalDetector.detect(makeCandles(closes))
        XCTAssertTrue(signals.contains { $0.kind == .bollingerUpperTouch })
    }

    func testBollingerLowerTouch_detected() {
        // 좁은 진동 → 아래로 스파이크(70) → 하단 띠 터치.
        let closes = (0..<20).map { $0 % 2 == 0 ? 102.0 : 98.0 } + [70, 70, 70, 70]
        let signals = ChartSignalDetector.detect(makeCandles(closes))
        XCTAssertTrue(signals.contains { $0.kind == .bollingerLowerTouch })
    }

    // MARK: 엣지

    // MARK: 지지/저항 (스윙 저점·고점)

    func testSupportBounce_atSwingLow() {
        // V자: 바닥(index 10, 100)이 ±5 안에서 최저 + 양 끝보다 낮음 → 지지선 반등.
        let closes: [Double] = [120, 118, 116, 114, 112, 110, 108, 106, 104, 102, 100,
                                102, 104, 106, 108, 110, 112, 114, 116, 118, 120, 122]
        let support = ChartSignalDetector.detect(makeCandles(closes)).filter { $0.kind == .supportBounce }
        XCTAssertEqual(support.map(\.candleIndex), [10])
        XCTAssertEqual(support.first?.subsequentDirection, .up) // 바닥 이후 반등
    }

    func testResistanceReject_atSwingHigh() {
        // 역V자: 천장(index 10, 120)이 ±5 안에서 최고 + 양 끝보다 높음 → 저항선 눌림.
        let closes: [Double] = [100, 102, 104, 106, 108, 110, 112, 114, 116, 118, 120,
                                118, 116, 114, 112, 110, 108, 106, 104, 102, 100, 98]
        let resist = ChartSignalDetector.detect(makeCandles(closes)).filter { $0.kind == .resistanceReject }
        XCTAssertEqual(resist.map(\.candleIndex), [10])
        XCTAssertEqual(resist.first?.subsequentDirection, .down) // 천장 이후 하락
    }

    func testFlatInput_noSupportResistance() {
        // 평탄 구간은 골/봉우리가 아니므로 지지/저항 신호 없음.
        let sr = ChartSignalDetector.detect(makeCandles(Array(repeating: 100.0, count: 30)))
            .filter { $0.kind == .supportBounce || $0.kind == .resistanceReject }
        XCTAssertTrue(sr.isEmpty)
    }

    func testEdge_shortInput_noSignals() {
        XCTAssertTrue(ChartSignalDetector.detect(makeCandles([1, 2, 3])).isEmpty)
        XCTAssertTrue(ChartSignalDetector.detect([]).isEmpty)
    }

    func testFlatInput_noSignals_includingBollinger() {
        // 완전 평탄(sd≈0): 크로스·RSI 없음 + 볼린저 터치도 억제되어야 함(밴드 폭 0).
        let signals = ChartSignalDetector.detect(makeCandles(Array(repeating: 100.0, count: 30)))
        XCTAssertTrue(signals.isEmpty)
    }

    func testNearFlatInput_suppressesBollingerTouch() {
        // 아주 미세한 변동(밴드 폭이 가격의 0.2% 미만)도 억제.
        let closes = (0..<30).map { 100.0 + (($0 % 2 == 0) ? 0.0 : 0.02) } // ±0.02 진동
        let bollinger = ChartSignalDetector.detect(makeCandles(closes)).filter {
            $0.kind == .bollingerUpperTouch || $0.kind == .bollingerLowerTouch
        }
        XCTAssertTrue(bollinger.isEmpty)
    }
}
