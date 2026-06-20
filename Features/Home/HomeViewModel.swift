import SwiftUI

/// 홈 "3초 브리핑" 상태. LoadDailyBriefing으로 관심종목 브리핑을 구성한다.
@MainActor
@Observable
final class HomeViewModel {
    enum State: Equatable {
        case loading
        case loaded(DailyBriefing)
        case empty          // 관심종목 없음
        case error(String)
    }

    private(set) var state: State = .loading
    private(set) var focusIndex = 0
    private(set) var isRefreshing = false
    private(set) var assetText = ""

    private let loadBriefing: LoadDailyBriefing
    private let auth: AuthRepository
    private let portfolio: PortfolioRepository

    init(loadBriefing: LoadDailyBriefing, auth: AuthRepository, portfolio: PortfolioRepository) {
        self.loadBriefing = loadBriefing
        self.auth = auth
        self.portfolio = portfolio
    }

    var stocks: [StockBriefing] {
        if case let .loaded(briefing) = state { return briefing.stocks }
        return []
    }

    func load() async {
        state = .loading
        await reload()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await reload()
    }

    func setFocus(_ index: Int) {
        guard index >= 0, index < stocks.count else { return }
        focusIndex = index
    }

    /// 뉴스 상세 진입점(스텁) — 시트 콘텐츠는 커밋 12.
    func openNewsDetail(stockCode: String, news: NewsItem) {
        // TODO(커밋 12): 뉴스 상세 시트 표시
    }

    private func reload() async {
        do {
            let user = try await auth.currentUser()
            let codes = user?.watchlistCodes ?? []
            guard !codes.isEmpty else {
                state = .empty
                return
            }
            let briefing = try await loadBriefing(watchlistCodes: codes)
            if let portfolio = try? await portfolio.fetchPortfolio() {
                assetText = Formatters.assetManwon(portfolio.cash.amount)
            }
            focusIndex = min(focusIndex, max(0, briefing.stocks.count - 1))
            state = .loaded(briefing)
        } catch {
            state = .error("소식을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.")
        }
    }
}
