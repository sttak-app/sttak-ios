import SwiftUI

// MARK: - PrimaryButton — 틸 CTA 버튼
//
// 핸드오프: 높이 56, radius 16(card), 글자 16/700(ctaLabel).
//   활성  : 배경 accent(#0FA39A), 글자 흰색, accentCTA 그림자.
//   비활성: 배경 ctaDisabledBackground(#E5E0D6), 글자 ctaDisabledForeground(#B3AC9D), 그림자 없음, 탭 불가.
//   로딩  : 스피너 표시, 탭 불가. (※ 로딩 비주얼은 핸드오프에 명시 없음 → 활성 배경 위 흰 스피너로 표준 처리)
// 내용은 title 파라미터, 상태는 State enum. 화면 로직 없음 — action 클로저만 받는다.
struct PrimaryButton: View {
    enum State {
        case enabled
        case disabled
        case loading
    }

    private let title: String
    private let state: State
    private let action: () -> Void

    /// 컴포넌트 고유 높이(핸드오프 56). 공유 스케일이 아닌 컴포넌트 내재 치수.
    private let height: CGFloat = 56

    init(_ title: String, state: State = .enabled, action: @escaping () -> Void) {
        self.title = title
        self.state = state
        self.action = action
    }

    private var isInteractive: Bool { state == .enabled }

    private var background: Color {
        switch state {
        case .enabled, .loading: return AppColor.accent
        case .disabled: return AppColor.ctaDisabledBackground
        }
    }

    private var foreground: Color {
        switch state {
        case .enabled, .loading: return .white
        case .disabled: return AppColor.ctaDisabledForeground
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(AppFont.ctaLabel)
                    .opacity(state == .loading ? 0 : 1)

                if state == .loading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .modifier(ConditionalShadow(enabled: state == .enabled))
        }
        .buttonStyle(.plain)
        .disabled(!isInteractive)
        .allowsHitTesting(isInteractive)
    }
}

/// 활성 상태에서만 CTA 그림자를 적용한다.
private struct ConditionalShadow: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled {
            content.appShadow(AppShadow.accentCTA)
        } else {
            content
        }
    }
}

#if DEBUG
#Preview("PrimaryButton") {
    VStack(spacing: AppSpacing.lg) {
        PrimaryButton("3개 담고 시작하기", state: .enabled) {}
        PrimaryButton("관심종목을 골라주세요", state: .disabled) {}
        PrimaryButton("불러오는 중", state: .loading) {}
    }
    .padding(AppSpacing.screenHorizontal)
    .background(AppColor.backgroundPrimary)
}
#endif
