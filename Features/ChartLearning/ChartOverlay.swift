import SwiftUI

/// 차트에 그릴 "무엇을"(데이터). 렌더러는 이 값만 받아 그린다(도메인 수식 재구현 없음).
/// 모든 값은 보이는 캔들 슬라이스에 정렬(날짜 기준).

struct DatedValue: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

struct MovingAverageLine: Identifiable {
    let period: Int
    let color: Color
    let points: [DatedValue]
    var id: Int { period }
}

struct BollingerPoint: Identifiable {
    let date: Date
    let upper: Double
    let middle: Double
    let lower: Double
    var id: Date { date }
}

struct SupportResistanceLevels: Equatable {
    let support: Double
    let resistance: Double
}

/// 신호 마커(차트 위) + 색칠 구간.
struct SignalMarker: Identifiable {
    let id: Int               // 번호(1..)
    let date: Date            // 신호 발생 봉
    let regionEnd: Date       // 색칠 구간 끝(이후 7봉)
    let high: Double          // 마커 위치용(봉 고가)
    let direction: PriceDirection
}

/// 가격 차트 위/아래 오버레이 전체.
struct ChartOverlay {
    var movingAverages: [MovingAverageLine] = []
    var bollinger: [BollingerPoint] = []
    var supportResistance: SupportResistanceLevels?
    var rsi: [DatedValue] = []          // 비어있지 않으면 RSI 하위 패널
    var showVolume: Bool = false        // 거래량 하위 패널
    var signals: [SignalMarker] = []
    var selectedDate: Date?

    var hasSubPanel: Bool { !rsi.isEmpty || showVolume }

    static let none = ChartOverlay()
}
