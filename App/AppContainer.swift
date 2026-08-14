import SwiftUI

/// Mock/Live 전환 seam. 앱 실행은 Info.plist `STTAK_ENV`(기본 live), 프리뷰·테스트는 Mock.
enum AppEnvironment {
    case mock
    case live

    static var current: AppEnvironment {
        // 우선순위: 런치 인자 > 프리뷰/테스트 자동 Mock > Info.plist STTAK_ENV > live.
        let process = ProcessInfo.processInfo
        if process.arguments.contains("-useLive") { return .live }
        if process.arguments.contains("-useMock") { return .mock }
        // 유닛테스트·SwiftUI 프리뷰는 네트워크 없이 결정적으로 — 항상 Mock.
        if process.environment["XCTestConfigurationFilePath"] != nil { return .mock }
        if process.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return .mock }
        switch (Bundle.main.object(forInfoDictionaryKey: "STTAK_ENV") as? String)?.lowercased() {
        case "mock": return .mock
        case "live": return .live
        default: return .live
        }
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
        case .mock:
            // 시드: "이미 써 온 사용자" 초기 상태(보유·매매기록·회고). 트레이드/퀴즈는 이 store를 공유.
            let store = MockLocalStore(cash: MockData.seedCash, holdings: MockData.seedHoldings, trades: MockData.seedTrades)
            self.auth = MockAuthRepository(store: store)
            self.news = MockNewsRepository()
            self.marketData = MockMarketDataRepository(store: store)
            self.chat = MockChatRepository()
            self.retrospective = MockRetrospectiveRepository()
            self.quiz = MockQuizRepository(store: store)
            self.portfolio = MockPortfolioRepository(store: store)
            self.ranking = MockRankingRepository()

        case .live:
            // Live 와이어링: 인증·뉴스·시세·캔들·퀴즈·챗봇·랭킹·포트폴리오/매매는 서버.
            // 회고(매도 직후 스트리밍은 제거, 정산 후 GET /trades 임베드) + 기초정보(PER/PBR)만 Mock.
            let config = AppConfig.default
            let tokenStore = KeychainTokenStore()
            let api = APIClient(config: config, tokenStore: tokenStore)

            self.auth = LiveAuthRepository(
                api: api,
                tokenStore: tokenStore,
                socialLogin: KakaoLoginService(isConfigured: config.isKakaoConfigured)
            )
            self.news = LiveNewsRepository(api: api)
            self.marketData = LiveMarketDataRepository(api: api)
            self.chat = LiveChatRepository(api: api)
            self.retrospective = MockRetrospectiveRepository()
            // 퀴즈 보상은 서버가 적립(SSOT). 포트폴리오가 Live라 로컬 미러는 이중 적립 → 제거.
            self.quiz = LiveQuizRepository(api: api)
            self.portfolio = LivePortfolioRepository(api: api)
            self.ranking = LiveRankingRepository(api: api)
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
            news: news,
            auth: auth,
            portfolio: portfolio
        )
    }

    @MainActor
    func makeNewsDetailViewModel(news: NewsItem, stockName: String) -> NewsDetailViewModel {
        NewsDetailViewModel(news: news, stockName: stockName, chat: chat)
    }

    @MainActor
    func makeChatViewModel() -> ChatViewModel {
        ChatViewModel(chat: chat, context: .free, greeting: MockData.freeChatGreeting)
    }

    @MainActor
    func makeRankingViewModel() -> RankingViewModel {
        RankingViewModel(
            ranking: ranking,
            evaluate: EvaluatePortfolio(portfolio: portfolio, market: marketData),
            auth: auth
        )
    }

    @MainActor
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(auth: auth)
    }

    @MainActor
    func makeMyViewModel() -> MyViewModel {
        MyViewModel(
            evaluate: EvaluatePortfolio(portfolio: portfolio, market: marketData),
            portfolio: portfolio,
            market: marketData
        )
    }

    @MainActor
    func makeQuizViewModel() -> QuizViewModel {
        QuizViewModel(quiz: quiz, portfolio: portfolio)
    }

    @MainActor
    func makeChartLearningViewModel() -> ChartLearningViewModel {
        ChartLearningViewModel(
            auth: auth, marketData: marketData, portfolioRepo: portfolio,
            evaluate: EvaluatePortfolio(portfolio: portfolio, market: marketData)
        )
    }

    @MainActor
    func makeTradeViewModel(intent: ChartLearningViewModel.TradeIntent, onCompleted: @escaping () -> Void) -> TradeViewModel {
        TradeViewModel(
            type: intent.type,
            stockCode: intent.stockCode,
            stockName: intent.stockName,
            price: intent.price,
            executeTrade: ExecuteTrade(portfolio: portfolio),
            portfolio: portfolio,
            onCompleted: onCompleted
        )
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
