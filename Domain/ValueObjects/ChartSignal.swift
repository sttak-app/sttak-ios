import Foundation

/// 차트 신호 종류. (차트학습 프로토타입의 신호 탐지 결과)
enum ChartSignalKind: Sendable, Equatable, CaseIterable {
    case goldenCross          // 골든크로스 (단기선이 장기선 상향 돌파)
    case deadCross            // 데드크로스
    case rsiOverbought        // RSI 과열(70↑)
    case rsiOversold          // RSI 과매도(30↓)
    case bollingerUpperTouch  // 볼린저 위 띠 터치
    case bollingerLowerTouch  // 볼린저 아래 띠 터치
}

/// 신호 이후 가격 흐름 방향.
enum PriceDirection: Sendable, Equatable {
    case up        // 상승
    case down      // 하락
    case sideways  // 횡보
}

/// 과거에 특정 신호가 떴던 지점. 설명문(교육 카피)은 kind로부터 표현 계층에서 생성한다.
struct ChartSignal: Sendable, Equatable {
    let kind: ChartSignalKind
    let candleIndex: Int                 // 신호가 발생한 캔들 인덱스
    let subsequentDirection: PriceDirection  // 이후 흐름 방향
}
