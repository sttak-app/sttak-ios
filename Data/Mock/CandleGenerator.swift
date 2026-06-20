import Foundation

/// 결정적 합성 캔들 생성기. `sttak 차트학습.dc.html`의 candles() 알고리즘(시드 random-walk →
/// 마지막 종가를 현재가로 스케일)을 이식했다.
/// 비고: 원본 JS는 double 오버플로 상태로 비트마스크하는 비정형 LCG라 값이 바이트 단위로 일치하진 않지만,
/// 동일 구조의 결정적 LCG로 같은 성질(시드 고정·240봉·현재가 스케일)을 재현한다. 실데이터는 Live(KIS)에서 온다.
enum CandleGenerator {
    private static let count = 240

    static func candles(seed: Int, base: Double, finalPrice: Double) -> [Candle] {
        var rng = LCG(seed: seed)
        var value = base
        var raw: [(o: Double, h: Double, l: Double, c: Double, v: Int)] = []
        raw.reserveCapacity(count)

        for i in 0..<count {
            let drift = (rng.next() - 0.47) * 0.022 + (i > 150 ? 0.001 : 0)
            let open = value
            let close = value * (1 + drift)
            let high = max(open, close) * (1 + rng.next() * 0.013)
            let low = min(open, close) * (1 - rng.next() * 0.013)
            let volume = Int(((0.5 + rng.next()) * 1.2e6).rounded())
            raw.append((open, high, low, close, volume))
            value = close
        }

        // 마지막 종가가 현재가가 되도록 전체 스케일.
        let scale = finalPrice / raw[count - 1].c
        let epoch: TimeInterval = 1_700_000_000 // 결정적 기준 시각
        return raw.enumerated().map { index, candle in
            Candle(
                date: Date(timeIntervalSince1970: epoch + Double(index) * 86_400),
                open: candle.o * scale,
                high: candle.h * scale,
                low: candle.l * scale,
                close: candle.c * scale,
                volume: candle.v
            )
        }
    }

    /// 선형 합동 생성기(0~1). 원본과 같은 상수(1103515245, 12345)·마스크(0x7fffffff) 사용.
    private struct LCG {
        private var state: UInt64
        init(seed: Int) { state = UInt64(bitPattern: Int64(seed &* 9301 &+ 49297)) }
        mutating func next() -> Double {
            state = state &* 1_103_515_245 &+ 12_345
            let masked = state & 0x7fff_ffff
            return Double(masked) / Double(0x7fff_ffff)
        }
    }
}
