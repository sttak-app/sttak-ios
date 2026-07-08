import Foundation

/// 차트 학습 지표 6종. 색·라벨 등 표현은 표현 계층에서 매핑한다.
enum IndicatorKind: Sendable, Equatable, CaseIterable {
    case info               // 정보(시총·PER·PBR)
    case supportResistance  // 지지·저항
    case movingAverage      // 이동평균선
    case rsi                // RSI
    case volume             // 거래량
    case bollingerBands     // 볼린저밴드
}
