import SwiftUI

/// 감정(도메인 Sentiment)의 표현 매핑. 도메인은 의미만 갖고, 라벨·색은 여기(표현 계층)서.
extension Sentiment {
    /// 한국어 라벨(배지 등).
    var label: String {
        switch self {
        case .positive: return "호재"
        case .neutral: return "중립"
        case .negative: return "악재"
        }
    }

    /// 점·텍스트 색(한국 증시 관례 + 정본 sentStyle).
    var color: Color {
        switch self {
        case .positive: return AppColor.sentimentPositive
        case .neutral: return AppColor.sentimentNeutral
        case .negative: return AppColor.sentimentNegative
        }
    }

    /// Badge 컴포넌트 종류.
    var badgeKind: Badge.Kind {
        switch self {
        case .positive: return .positive
        case .neutral: return .neutral
        case .negative: return .negative
        }
    }
}
