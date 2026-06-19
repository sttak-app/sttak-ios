import SwiftUI

/// 최소 스켈레톤 루트 화면.
///
/// 아직 기능 코드는 없다. 종이톤 배경 위에 브랜드 마크와 워드마크만 표시해
/// 앱이 정상 부팅·렌더되는지, 디자인 토큰이 적용되는지 확인한다.
/// 실제 홈 화면(Features/Home)·라우팅은 이후 커밋에서 대체한다.
struct RootView: View {
    var body: some View {
        ZStack {
            AppColor.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.xl) {
                ReticleLogo(size: 78)

                VStack(spacing: AppSpacing.sm) {
                    Text("sttak")
                        .font(AppFont.splashWordmark)
                        .kerning(-1.2)
                        .foregroundStyle(AppColor.ink)

                    Text("데이터로 시작하는 첫 투자")
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.textMuted)
                }
            }
        }
    }
}

#Preview {
    RootView()
}
