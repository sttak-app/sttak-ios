import Foundation

/// 차트 지표 계산(온디바이스 순수 함수). 입력 [Candle] → 결과 배열(입력과 같은 길이).
/// 공식·파라미터는 docs/ 핸드오프(`sttak 차트학습.dc.html`의 ma/rsi/boll)와 동일하게 고정한다.
/// 모든 함수는 결정적이며, 캔들 수가 기간보다 적은 구간은 nil(크래시 금지).
enum Indicators {

    /// 단순이동평균(SMA). i < period-1 은 nil, 그 외 최근 period개 종가 평균.
    static func simpleMovingAverage(_ candles: [Candle], period: Int) -> [Double?] {
        let n = candles.count
        var result = [Double?](repeating: nil, count: n)
        guard period > 0, n >= period else { return result }
        var windowSum = 0.0
        for i in 0..<n {
            windowSum += candles[i].close
            if i >= period { windowSum -= candles[i - period].close }
            if i >= period - 1 { result[i] = windowSum / Double(period) }
        }
        return result
    }

    /// RSI — Wilder 평활. 첫 값은 i = period 에서 초기 period개 변화량의 단순평균으로 계산하고,
    /// 이후는 Wilder 점화식 `avg = (avg·(p-1) + 현재) / p` 로 갱신한다.
    /// i < period 는 nil. 손실 평균이 0이면 분모를 1e-9로 대체(핸드오프 `l || 1e-9` 동일).
    static func relativeStrengthIndex(_ candles: [Candle], period: Int = 14) -> [Double?] {
        let n = candles.count
        var result = [Double?](repeating: nil, count: n)
        guard period > 0, n > period else { return result }

        var avgGain = 0.0
        var avgLoss = 0.0
        for i in 1..<n {
            let delta = candles[i].close - candles[i - 1].close
            let up = max(delta, 0)
            let down = max(-delta, 0)
            if i <= period {
                avgGain += up
                avgLoss += down
                if i == period {
                    avgGain /= Double(period)
                    avgLoss /= Double(period)
                    result[i] = rsiValue(avgGain: avgGain, avgLoss: avgLoss)
                }
                // i < period → nil 유지
            } else {
                avgGain = (avgGain * Double(period - 1) + up) / Double(period)
                avgLoss = (avgLoss * Double(period - 1) + down) / Double(period)
                result[i] = rsiValue(avgGain: avgGain, avgLoss: avgLoss)
            }
        }
        return result
    }

    /// 볼린저밴드. 중간선 = SMA(period), 상/하 = 중간선 ± multiplier·모표준편차(÷period).
    /// i < period-1 은 nil.
    static func bollingerBands(
        _ candles: [Candle],
        period: Int = 20,
        multiplier: Double = 2
    ) -> (middle: [Double?], upper: [Double?], lower: [Double?]) {
        let n = candles.count
        let middle = simpleMovingAverage(candles, period: period)
        var upper = [Double?](repeating: nil, count: n)
        var lower = [Double?](repeating: nil, count: n)
        guard period > 0, n >= period else { return (middle, upper, lower) }

        for i in (period - 1)..<n {
            guard let mean = middle[i] else { continue }
            var sumOfSquares = 0.0
            for j in (i - period + 1)...i {
                let diff = candles[j].close - mean
                sumOfSquares += diff * diff
            }
            let standardDeviation = (sumOfSquares / Double(period)).squareRoot()
            upper[i] = mean + multiplier * standardDeviation
            lower[i] = mean - multiplier * standardDeviation
        }
        return (middle, upper, lower)
    }

    // MARK: - 내부

    private static func rsiValue(avgGain: Double, avgLoss: Double) -> Double {
        let rs = avgGain / (avgLoss == 0 ? 1e-9 : avgLoss)
        return 100 - 100 / (1 + rs)
    }
}
