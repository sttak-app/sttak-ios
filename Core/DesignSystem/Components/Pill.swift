import SwiftUI

// MARK: - Pill — 완전 둥근(999) 칩/필
//
// 핸드오프에 여러 변형이 있어, 색·보더·그림자·폰트를 PillStyle 로 묶고 실측 프리셋을 제공한다.
// 컴포넌트는 모양만 담당(화면 로직 없음). 내용은 text 또는 커스텀 content 로 받는다.
struct PillStyle: Sendable {
    var foreground: Color
    var background: Color
    var border: Color? = nil
    var shadow: ShadowToken? = nil
    var font: Font = AppFont.metaCaption
    var horizontalPadding: CGFloat = AppSpacing.md
    var verticalPadding: CGFloat = AppSpacing.xs

    // ── 핸드오프 실측 프리셋 ──

    /// 빠른질문 칩: 옅은 틸 틴트.
    static let accentSoft = PillStyle(
        foreground: AppColor.accentDeep, background: AppColor.accentTintSoft,
        font: AppFont.bodyStrong, horizontalPadding: AppSpacing.md, verticalPadding: AppSpacing.sm
    )
    /// 카운트 필 활성(n/5, 선택 있음): 틸 틴트 + 보더, 숫자 폰트.
    static let accentSelected = PillStyle(
        foreground: AppColor.accentDeep, background: AppColor.accentTint, border: AppColor.accentTintBorder,
        font: AppFont.number(14), horizontalPadding: AppSpacing.md, verticalPadding: AppSpacing.xs
    )
    /// 카운트 필 비활성(선택 0): 흰 배경 + 옅은 보더, 숫자 폰트.
    static let neutralOutline = PillStyle(
        foreground: AppColor.textMuted2, background: AppColor.surface, border: AppColor.controlBorder,
        font: AppFont.number(14), horizontalPadding: AppSpacing.md, verticalPadding: AppSpacing.xs
    )
    /// 섹터/메타 칩: 중립 틴트.
    static let neutral = PillStyle(
        foreground: AppColor.textMuted, background: AppColor.surfaceChip,
        font: AppFont.microCaption, horizontalPadding: AppSpacing.sm, verticalPadding: AppSpacing.xxs
    )
    /// 보유자산/스트릭 칩: 흰 표면 + 옅은 그림자.
    static let surface = PillStyle(
        foreground: AppColor.ink, background: AppColor.surface, shadow: AppShadow.chip,
        font: AppFont.metaCaption, horizontalPadding: AppSpacing.md, verticalPadding: AppSpacing.sm
    )
    /// 토스트: 다크.
    static let dark = PillStyle(
        foreground: .white, background: AppColor.ink,
        font: AppFont.bodyStrong, horizontalPadding: AppSpacing.lg, verticalPadding: AppSpacing.sm
    )
}

struct Pill<Content: View>: View {
    private let style: PillStyle
    private let content: Content

    init(style: PillStyle, @ViewBuilder content: () -> Content) {
        self.style = style
        self.content = content()
    }

    var body: some View {
        content
            .font(style.font)
            .foregroundStyle(style.foreground)
            .padding(.horizontal, style.horizontalPadding)
            .padding(.vertical, style.verticalPadding)
            .background(style.background)
            .clipShape(Capsule())
            .overlay {
                if let border = style.border {
                    Capsule().stroke(border, lineWidth: 1)
                }
            }
            .modifier(OptionalPillShadow(shadow: style.shadow))
            .fixedSize()
    }
}

extension Pill where Content == Text {
    /// 텍스트 전용 간편 생성자.
    init(_ text: String, style: PillStyle) {
        self.init(style: style) { Text(text) }
    }
}

private struct OptionalPillShadow: ViewModifier {
    let shadow: ShadowToken?
    func body(content: Content) -> some View {
        if let shadow {
            content.appShadow(shadow)
        } else {
            content
        }
    }
}

#if DEBUG
#Preview("Pill") {
    VStack(alignment: .leading, spacing: AppSpacing.md) {
        Pill("이게 왜 중요한가요?", style: .accentSoft)
        HStack(spacing: AppSpacing.sm) {
            Pill("3/5", style: .accentSelected)
            Pill("0/5", style: .neutralOutline)
        }
        Pill("반도체", style: .neutral)
        Pill("보유 자산 1,000만원", style: .surface)
        Pill("최대 5개까지 담을 수 있어요", style: .dark)
    }
    .padding(AppSpacing.screenHorizontal)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(AppColor.backgroundPrimary)
}
#endif
