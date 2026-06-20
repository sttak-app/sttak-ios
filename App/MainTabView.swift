import SwiftUI

/// 인증 후 메인 셸. 핸드오프 확정 4탭(홈·차트학습·퀴즈·마이). 랭킹은 별도 탭이 아니라
/// 마이 안에서 진입한다. 각 탭 콘텐츠는 placeholder — 실제 화면은 커밋 11+.
struct MainTabView: View {
    @State private var selection: Tab = .home

    enum Tab: Hashable {
        case home, chart, quiz, my
    }

    var body: some View {
        TabView(selection: $selection) {
            tab(.home, title: "홈", systemImage: "house")
            tab(.chart, title: "차트학습", systemImage: "chart.xyaxis.line")
            tab(.quiz, title: "퀴즈", systemImage: "checkmark.circle")
            tab(.my, title: "마이", systemImage: "person")
        }
        .tint(AppColor.accent)
    }

    private func tab(_ tab: Tab, title: String, systemImage: String) -> some View {
        TabPlaceholderView(title: title)
            .tabItem { Label(title, systemImage: systemImage) }
            .tag(tab)
    }
}

/// 탭 콘텐츠 placeholder.
private struct TabPlaceholderView: View {
    let title: String

    var body: some View {
        ZStack {
            AppColor.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: AppSpacing.sm) {
                ReticleLogo(size: 40)
                    .padding(.bottom, AppSpacing.sm)
                Text(title)
                    .font(AppFont.screenTitle)
                    .foregroundStyle(AppColor.ink)
                Text("준비 중 — 실제 화면은 다음 커밋에서")
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.textMuted)
            }
        }
    }
}

#if DEBUG
#Preview {
    MainTabView()
}
#endif
