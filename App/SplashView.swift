import SwiftUI

/// 스플래시 — 브랜드 첫인상. 핸드오프 기준: 리테클 로고(78) → 워드마크(40/700) → 태그라인.
/// 자동 전환은 RootViewModel 타이머가, 즉시 전환은 탭(onTap)이 담당한다.
struct SplashView: View {
    var onTap: () -> Void = {}

    @State private var appeared = false

    var body: some View {
        ZStack {
            AppColor.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: AppSpacing.xl) {
                ReticleLogo(size: 78)
                    .scaleEffect(appeared ? 1 : 0.7)
                    .opacity(appeared ? 1 : 0)

                VStack(spacing: AppSpacing.sm) {
                    Text("sttak")
                        .font(AppFont.splashWordmark)
                        .kerning(-1.2)
                        .foregroundStyle(AppColor.ink)

                    Text("데이터로 시작하는 첫 투자")
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.textMuted)
                }
                .opacity(appeared ? 1 : 0)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { appeared = true }
        }
    }
}

#if DEBUG
#Preview { SplashView() }
#endif
