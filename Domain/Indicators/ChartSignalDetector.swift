import Foundation

/// 과거 신호 탐지(온디바이스 순수 함수). 입력 [Candle] → 탐지된 [ChartSignal].
/// 파라미터·규칙은 docs/ 핸드오프 `computeSignals`와 동일하게 고정한다.
///
/// 신호 4종: 골든/데드크로스(MA5×MA20), RSI 과열/과매도(70 상향·30 하향 돌파),
/// 볼린저 상·하단 터치. 각 신호는 가드 `i ∈ [5, count-2]`를 통과해야 한다(워밍업/미래캔들 필요).
///
/// 비고: 핸드오프 `computeSignals`의 루프 시작값(21/15/20)은 구현 디테일이라, 여기선
/// 지표가 정의된 모든 인덱스에서 탐지한다(프로토타입이 건너뛴 최초 1개 인덱스까지 포함하는 상위집합).
/// 또한 핸드오프의 "최근 3개로 추림·5봉 내 병합"은 표현 계층 관심사라 도메인에선 모든 신호를 반환한다.
enum ChartSignalDetector {

    // ── 고정 파라미터 (핸드오프) ──
    static let shortMAPeriod = 5
    static let longMAPeriod = 20
    static let rsiPeriod = 14
    static let rsiOverboughtLevel = 70.0
    static let rsiOversoldLevel = 30.0
    static let bollingerPeriod = 20
    static let bollingerMultiplier = 2.0
    static let forwardWindow = 7              // 이후 방향 판정에 보는 거래일 수
    static let directionThresholdPercent = 1.5 // ±1.5% 밖이면 up/down, 안이면 sideways
    static let minimumIndex = 5               // 워밍업 가드

    static func detect(_ candles: [Candle]) -> [ChartSignal] {
        let n = candles.count
        guard n >= 2 else { return [] }
        var signals: [ChartSignal] = []

        // 골든/데드크로스 — MA5 × MA20
        let maShort = Indicators.simpleMovingAverage(candles, period: shortMAPeriod)
        let maLong = Indicators.simpleMovingAverage(candles, period: longMAPeriod)
        for i in 1..<n {
            guard let aPrev = maShort[i - 1], let bPrev = maLong[i - 1],
                  let aCur = maShort[i], let bCur = maLong[i] else { continue }
            if aPrev <= bPrev && aCur > bCur {
                appendSignal(&signals, .goldenCross, at: i, in: candles)
            } else if aPrev >= bPrev && aCur < bCur {
                appendSignal(&signals, .deadCross, at: i, in: candles)
            }
        }

        // RSI — 70 상향 돌파(과열) / 30 하향 돌파(과매도)
        let rsi = Indicators.relativeStrengthIndex(candles, period: rsiPeriod)
        for i in 1..<n {
            guard let prev = rsi[i - 1], let cur = rsi[i] else { continue }
            if prev < rsiOverboughtLevel && cur >= rsiOverboughtLevel {
                appendSignal(&signals, .rsiOverbought, at: i, in: candles)
            } else if prev > rsiOversoldLevel && cur <= rsiOversoldLevel {
                appendSignal(&signals, .rsiOversold, at: i, in: candles)
            }
        }

        // 볼린저밴드 터치
        let bands = Indicators.bollingerBands(candles, period: bollingerPeriod, multiplier: bollingerMultiplier)
        for i in 0..<n {
            guard let upper = bands.upper[i], let lower = bands.lower[i] else { continue }
            let close = candles[i].close
            if close >= upper {
                appendSignal(&signals, .bollingerUpperTouch, at: i, in: candles)
            } else if close <= lower {
                appendSignal(&signals, .bollingerLowerTouch, at: i, in: candles)
            }
        }

        return signals.sorted { lhs, rhs in
            lhs.candleIndex != rhs.candleIndex
                ? lhs.candleIndex < rhs.candleIndex
                : kindOrder(lhs.kind) < kindOrder(rhs.kind)
        }
    }

    // MARK: - 내부

    private static func appendSignal(
        _ signals: inout [ChartSignal],
        _ kind: ChartSignalKind,
        at index: Int,
        in candles: [Candle]
    ) {
        // push 가드: 워밍업(<5) / 미래 캔들 없음(>count-2) 제외
        guard index >= minimumIndex, index <= candles.count - 2 else { return }
        signals.append(
            ChartSignal(
                kind: kind,
                candleIndex: index,
                subsequentDirection: subsequentDirection(in: candles, at: index)
            )
        )
    }

    private static func subsequentDirection(in candles: [Candle], at index: Int) -> PriceDirection {
        let target = min(candles.count - 1, index + forwardWindow)
        let base = candles[index].close
        guard base != 0 else { return .sideways }
        let percentChange = (candles[target].close - base) / base * 100
        if percentChange > directionThresholdPercent { return .up }
        if percentChange < -directionThresholdPercent { return .down }
        return .sideways
    }

    private static func kindOrder(_ kind: ChartSignalKind) -> Int {
        switch kind {
        case .goldenCross: return 0
        case .deadCross: return 1
        case .rsiOverbought: return 2
        case .rsiOversold: return 3
        case .bollingerUpperTouch: return 4
        case .bollingerLowerTouch: return 5
        }
    }
}
