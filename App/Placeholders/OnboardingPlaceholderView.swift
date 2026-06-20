import SwiftUI

/// 미인증 도착지 placeholder. 실제 로그인/온보딩은 커밋 10.
/// "로그인(목업)" 버튼으로 인증 상태(탭 셸)로 넘어가 볼 수 있다.
struct OnboardingPlaceholderView: View {
    var onSignIn: () -> Void = {}

    var body: some View {
        ZStack {
            AppColor.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: AppSpacing.xl) {
                ReticleLogo(size: 52)

                VStack(spacing: AppSpacing.sm) {
                    Text("로그인 · 온보딩")
                        .font(AppFont.screenTitle)
                        .foregroundStyle(AppColor.ink)
                    Text("실제 화면은 다음 단계에서 만들어요 (커밋 10)")
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.textMuted)
                        .multilineTextAlignment(.center)
                }

                PrimaryButton("로그인(목업)으로 시작하기", action: onSignIn)
                    .padding(.top, AppSpacing.sm)
            }
            .padding(AppSpacing.screenHorizontal)
        }
    }
}

#if DEBUG
#Preview {
    OnboardingPlaceholderView()
}
#endif
