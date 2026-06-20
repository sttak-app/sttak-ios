import SwiftUI

/// 지표·신호의 표현 계층 정적 카피(라벨·색·쉬운 설명). 핸드오프 텍스트 그대로 추출 — 도메인/LLM 아님.
enum IndicatorCopy {

    // MARK: 지표 칩
    static let panelOrder: [IndicatorKind] = [.info, .supportResistance, .movingAverage, .rsi, .volume, .bollingerBands]

    static func label(_ kind: IndicatorKind) -> String {
        switch kind {
        case .info: return "정보"
        case .supportResistance: return "지지·저항"
        case .movingAverage: return "이동평균선"
        case .rsi: return "RSI"
        case .volume: return "거래량"
        case .bollingerBands: return "볼린저밴드"
        }
    }

    /// 칩 점 색.
    static func dotColor(_ kind: IndicatorKind) -> Color {
        switch kind {
        case .info: return AppColor.indicatorInfo
        case .supportResistance: return AppColor.indicatorSupportResist
        case .movingAverage: return AppColor.indicatorMA
        case .rsi: return AppColor.indicatorRSI
        case .volume: return AppColor.priceUp
        case .bollingerBands: return AppColor.accent
        }
    }

    // MARK: 코치 설명(지표별)
    static func coachTitle(_ kind: IndicatorKind?) -> String {
        guard let kind else { return "sttak 차트 코치" }
        switch kind {
        case .info: return "정보 · 회사의 몸값"
        case .supportResistance: return "지지·저항 · 바닥과 천장"
        case .movingAverage: return "이동평균선 · 추세"
        case .rsi: return "RSI · 과열과 침체"
        case .volume: return "거래량 · 관심의 크기"
        case .bollingerBands: return "볼린저밴드 · 변동폭 띠"
        }
    }

    static func coachBody(_ kind: IndicatorKind?) -> String {
        guard let kind else {
            return "아래 용어를 누르면, 과거에 그 신호가 나타났던 구간을 차트에 색칠해 표시하고 그 뒤 흐름을 함께 보여드려요. 숫자보다 ‘흐름’을 먼저 익혀 보세요."
        }
        switch kind {
        case .info:
            return "시가총액은 회사 전체의 몸값, PER은 이익 대비, PBR은 자산 대비 주가가 비싼지를 보는 숫자예요. 낮을수록 ‘싸다’고 보지만 업종마다 기준이 달라요."
        case .supportResistance:
            return "지지선은 가격이 잘 안 내려가는 바닥, 저항선은 잘 못 넘는 천장이에요. 자주 부딪힌 가격일수록 의미가 커요."
        case .movingAverage:
            return "최근 며칠 종가의 평균을 이은 선이에요. 짧은 선(5일)이 긴 선(20일)을 위로 뚫는 ‘골든크로스’는 상승 전환 신호로 자주 봐요. 선 위에 가격이 있으면 흐름이 ‘위쪽’이에요."
        case .rsi:
            return "최근 상승·하락 힘을 0~100으로 나타내요. 70 위는 과열(비쌀 수 있음), 30 아래는 과매도(쌀 수 있음)로 읽어요."
        case .volume:
            return "하루에 얼마나 거래됐는지예요. 가격이 오를 때 거래량도 함께 늘면 관심이 실린 상승으로 봐요."
        case .bollingerBands:
            return "평균선 위아래로 변동폭만큼 띠를 그린 거예요. 위 띠에 닿으면 단기 과열, 아래 띠에 닿으면 단기 과매도로 봐요."
        }
    }

    // MARK: 신호
    static func signalLabel(_ kind: ChartSignalKind) -> String {
        switch kind {
        case .goldenCross: return "골든크로스"
        case .deadCross: return "데드크로스"
        case .rsiOverbought: return "RSI 과열(70↑)"
        case .rsiOversold: return "RSI 과매도(30↓)"
        case .bollingerUpperTouch: return "위 띠 터치"
        case .bollingerLowerTouch: return "아래 띠 터치"
        }
    }

    static func signalDescription(_ kind: ChartSignalKind) -> String {
        switch kind {
        case .goldenCross:
            return "단기 이동평균선(5일)이 장기선(20일)을 아래에서 위로 뚫었어요. 짧은 흐름이 위로 돌아섰다고 보는 자리예요."
        case .deadCross:
            return "단기선(5일)이 장기선(20일)을 위에서 아래로 뚫었어요. 짧은 흐름이 아래로 꺾였다고 보는 자리예요."
        case .rsiOverbought:
            return "RSI가 70을 넘어 ‘과열’ 구간에 들어섰어요. 단기적으로 많이 올라 비쌀 수 있다는 뜻이에요."
        case .rsiOversold:
            return "RSI가 30 아래로 내려가 ‘과매도’ 구간이에요. 단기적으로 많이 빠져 쌀 수 있다는 뜻이에요."
        case .bollingerUpperTouch:
            return "가격이 볼린저밴드 위쪽 띠에 닿았어요. 단기적으로 과열로 보는 자리예요."
        case .bollingerLowerTouch:
            return "가격이 볼린저밴드 아래쪽 띠에 닿았어요. 단기적으로 과매도로 보는 자리예요."
        }
    }

    /// 신호 이후 7거래일 흐름 설명.
    static func afterText(_ direction: PriceDirection) -> String {
        switch direction {
        case .up: return "이후 7거래일 동안 가격이 오르는 흐름이 이어졌어요."
        case .down: return "이후 7거래일 동안 가격이 내리는 흐름이었어요."
        case .sideways: return "이후 7거래일 동안 큰 변화 없이 횡보했어요."
        }
    }

    static func directionLabel(_ direction: PriceDirection) -> String {
        switch direction {
        case .up: return "7일 뒤 상승 흐름"
        case .down: return "7일 뒤 하락 흐름"
        case .sideways: return "7일 뒤 횡보"
        }
    }

    static func directionColor(_ direction: PriceDirection) -> Color {
        switch direction {
        case .up: return AppColor.priceUp
        case .down: return AppColor.priceDown
        case .sideways: return AppColor.priceFlat
        }
    }

    /// 이 지표가 시각화하는 신호 종류(없으면 빈 배열).
    static func signalKinds(_ kind: IndicatorKind) -> [ChartSignalKind] {
        switch kind {
        case .movingAverage: return [.goldenCross, .deadCross]
        case .rsi: return [.rsiOverbought, .rsiOversold]
        case .bollingerBands: return [.bollingerUpperTouch, .bollingerLowerTouch]
        case .info, .supportResistance, .volume: return []
        }
    }
}
