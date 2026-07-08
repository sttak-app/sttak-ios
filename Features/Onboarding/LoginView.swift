import SwiftUI

/// 로그인 화면. 핸드오프 기준: 작은 로고 → 헤드라인 → 서브카피 → 소셜 버튼 묶음 → 약관.
/// 버튼은 UI만 — Mock AuthRepository로 인증(실제 SDK는 Live). Apple은 확정 B4로 추가.
struct LoginView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onLoggedIn: () -> Void

    var body: some View {
        ZStack {
            AppColor.backgroundPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                ReticleLogo(size: 52)
                    .padding(.bottom, AppSpacing.xxl)

                Text("처음이어도 괜찮아요.\n투자, 쉽게 시작해요")
                    .font(AppFont.loginHeadline)
                    .foregroundStyle(AppColor.ink)
                    .lineSpacing(6)
                    .padding(.bottom, AppSpacing.sm)

                Text("관심종목 뉴스를 호재·악재로 정리하고,\n모의투자로 안전하게 연습해요.")
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.textMuted)
                    .lineSpacing(4)

                Spacer()

                VStack(spacing: AppSpacing.md) {
                    SocialLoginButton(style: .kakao, title: "카카오로 시작하기") { login(.kakao) }
                    SocialLoginButton(style: .apple, title: "Apple로 계속하기") { login(.apple) }
                    SocialLoginButton(style: .google, title: "Google로 계속하기") { login(.google) }

                    // 카카오 키 미설정(플레이스홀더) 동안의 dev 폴백 — X-User-Id 헤더 인증.
                    if !AppConfig.default.isKakaoConfigured {
                        Button { login(.dev) } label: {
                            Text("개발자 로그인")
                                .font(AppFont.metaCaption)
                                .foregroundStyle(AppColor.textMuted)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                        }
                        .buttonStyle(.plain)
                    }

                    if let error = viewModel.loginError {
                        Text(error)
                            .font(AppFont.microCaption)
                            .foregroundStyle(AppColor.sentimentPositive)
                            .multilineTextAlignment(.center)
                    }

                    Text("가입 시 이용약관 및 개인정보 처리방침에 동의하게 됩니다")
                        .font(AppFont.microCaption)
                        .foregroundStyle(AppColor.textMuted2)
                        .multilineTextAlignment(.center)
                        .padding(.top, AppSpacing.xs)
                }
                .disabled(viewModel.isAuthenticating)
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.vertical, AppSpacing.xxl)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func login(_ provider: AuthProvider) {
        Task {
            if await viewModel.signIn(with: provider) { onLoggedIn() }
        }
    }
}

/// 소셜 로그인 버튼(브랜드별 색). 로고 아이콘은 실제 SDK 공식 에셋으로 교체 예정.
struct SocialLoginButton: View {
    enum Style { case kakao, google, apple }

    let style: Style
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.ctaLabel)
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                .overlay {
                    if style == .google {
                        RoundedRectangle(cornerRadius: AppRadius.card)
                            .stroke(AppColor.controlBorder, lineWidth: 1.5)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var background: Color {
        switch style {
        case .kakao: return AppColor.kakao
        case .google: return AppColor.surface
        case .apple: return AppColor.ink
        }
    }

    private var foreground: Color {
        switch style {
        case .kakao: return AppColor.kakaoText
        case .google: return AppColor.ink
        case .apple: return .white
        }
    }
}
