import SwiftUI

/// Mock/Live 전환 seam. 기본은 Mock. Live 와이어링은 OpenAPI 스펙 확정까지 보류.
enum AppEnvironment {
    case mock
    case live

    static var current: AppEnvironment {
        // 단일 전환 지점 — 나중에 런치 인자/빌드 설정으로 Live 선택.
        ProcessInfo.processInfo.arguments.contains("-useLive") ? .live : .mock
    }
}

/// DI 컴포지션 루트. 8개 Repository를 한 곳에서 수동 조립한다(전역 가변 싱글톤 금지).
/// 앱 시작 시 1회 생성해 SwiftUI Environment로 하위에 주입한다. ViewModel은 이 컨테이너의
/// 팩토리로 만든다.
final class AppContainer: Sendable {
    let auth: AuthRepository
    let news: NewsRepository
    let marketData: MarketDataRepository
    let chat: ChatRepository
    let retrospective: RetrospectiveRepository
    let quiz: QuizRepository
    let portfolio: PortfolioRepository
    let ranking: RankingRepository

    init(environment: AppEnvironment = .current) {
        switch environment {
        case .mock, .live:
            // ⬇︎ 여기가 Mock→Live 교체의 단일 지점. 지금은 전부 Mock.
            //   (OpenAPI 확정 후 .live 분기에서 Live* 구현으로 바꾸면 됨)
            let store = MockLocalStore()
            self.auth = MockAuthRepository(store: store)
            self.news = MockNewsRepository()
            self.marketData = MockMarketDataRepository()
            self.chat = MockChatRepository()
            self.retrospective = MockRetrospectiveRepository()
            self.quiz = MockQuizRepository(store: store)
            self.portfolio = MockPortfolioRepository(store: store)
            self.ranking = MockRankingRepository()
        }
    }

    // MARK: ViewModel 팩토리 (피처가 늘면 여기 추가)
    @MainActor
    func makeRootViewModel() -> RootViewModel {
        RootViewModel(auth: auth)
    }

    @MainActor
    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(auth: auth, marketData: marketData)
    }

    @MainActor
    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            loadBriefing: LoadDailyBriefing(marketData: marketData, news: news),
            auth: auth,
            portfolio: portfolio
        )
    }

    @MainActor
    func makeNewsDetailViewModel(news: NewsItem, stockName: String) -> NewsDetailViewModel {
        NewsDetailViewModel(news: news, stockName: stockName, chat: chat)
    }
}

// MARK: - Environment 주입

private struct AppContainerKey: EnvironmentKey {
    static let defaultValue = AppContainer()
}

extension EnvironmentValues {
    var container: AppContainer {
        get { self[AppContainerKey.self] }
        set { self[AppContainerKey.self] = newValue }
    }
}
