import SwiftUI

// MARK: - Badge — 감정(호재/중립/악재) 배지
//
// 핸드오프 정본: `sttak Home.dc.html` sentStyle(). 작은 라운드 사각(radius 7, pill 아님),
// 글자 11.5/700. 색은 커밋 3 토큰. 내용(라벨)은 파라미터, 상태는 BadgeKind enum.
struct Badge: View {
    enum Kind {
        case positive  // 호재
        case neutral   // 중립
        case negative  // 악재

        var foreground: Color {
            switch self {
            case .positive: return AppColor.sentimentPositive
            case .neutral: return AppColor.sentimentNeutral
            case .negative: return AppColor.sentimentNegative
            }
        }

        var background: Color {
            switch self {
            case .positive: return AppColor.sentimentPositiveTint
            case .neutral: return AppColor.sentimentNeutralTint
            case .negative: return AppColor.sentimentNegativeTint
            }
        }
    }

    let text: String
    let kind: Kind

    init(_ text: String, kind: Kind) {
        self.text = text
        self.kind = kind
    }

    var body: some View {
        Text(text)
            .font(AppFont.badge)
            .foregroundStyle(kind.foreground)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xxs)
            .background(kind.background)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.badge))
            .fixedSize()
    }
}

#if DEBUG
#Preview("Badge") {
    HStack(spacing: AppSpacing.sm) {
        Badge("호재", kind: .positive)
        Badge("중립", kind: .neutral)
        Badge("악재", kind: .negative)
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}
#endif
