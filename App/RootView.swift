import SwiftUI

/// 앱 최상위 뷰. RootViewModel.phase에 따라 스플래시 → (미인증)온보딩 / (인증)탭 셸로 전환한다.
struct RootView: View {
    @Environment(\.container) private var container
    @State private var viewModel: RootViewModel?

    var body: some View {
        Group {
            switch viewModel?.phase {
            case .none, .splash:
                SplashView(onTap: { Task { await viewModel?.skipSplash() } })
            case .unauthenticated:
                OnboardingPlaceholderView(onSignIn: { Task { await viewModel?.signInWithMock() } })
            case .authenticated:
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: viewModel?.phase)
        .task {
            if viewModel == nil {
                viewModel = container.makeRootViewModel()
                await viewModel?.start()
            }
        }
    }
}

#if DEBUG
#Preview {
    RootView()
}
#endif
