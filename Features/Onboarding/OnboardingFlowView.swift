import SwiftUI

/// 온보딩 플로우: 로그인 → 관심종목 선택(NavigationStack). 완료 시 onComplete로 인증 전환 신호.
/// ViewModel은 AppContainer 팩토리로 생성(커밋 9 방식).
struct OnboardingFlowView: View {
    @Environment(\.container) private var container
    let onComplete: () -> Void

    @State private var viewModel: OnboardingViewModel?
    @State private var path: [Route] = []

    private enum Route: Hashable { case watchlist }

    var body: some View {
        Group {
            if let viewModel {
                NavigationStack(path: $path) {
                    LoginView(viewModel: viewModel, onLoggedIn: { path.append(.watchlist) })
                        .navigationDestination(for: Route.self) { route in
                            switch route {
                            case .watchlist:
                                WatchlistSelectionView(viewModel: viewModel, onComplete: onComplete)
                            }
                        }
                }
            } else {
                AppColor.backgroundPrimary.ignoresSafeArea()
            }
        }
        .task {
            if viewModel == nil { viewModel = container.makeOnboardingViewModel() }
        }
    }
}
