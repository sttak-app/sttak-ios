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

    struct PresentedNews: Identifiable, Equatable {
        let id: Int
        let stockName: String
        let news: NewsItem
    }

    private(set) var state: State = .loading
    private(set) var focusIndex = 0
    private(set) var isRefreshing = false
    private(set) var assetText = ""
    private(set) var presentedNews: PresentedNews?
    private var presentationCounter = 0

    // 종목별 무한 스크롤 상태(첫 페이지는 브리핑이 제공, 이후는 커서로 이어 붙인다).
    private var appendedNews: [String: [NewsItem]] = [:]   // 첫 페이지 이후 누적된 뉴스
    private var nextCursors: [String: String] = [:]        // 종목별 다음 페이지 커서(없으면 부재)
    private var hasMoreByCode: [String: Bool] = [:]        // 종목별 더보기 가능 여부
    private var loadingMore: Set<String> = []              // 현재 더보기 진행 중인 종목

    private let loadBriefing: LoadDailyBriefing
    private let news: NewsRepository
    private let auth: AuthRepository
    private let portfolio: PortfolioRepository

    init(loadBriefing: LoadDailyBriefing, news: NewsRepository, auth: AuthRepository, portfolio: PortfolioRepository) {
        self.loadBriefing = loadBriefing
        self.news = news
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

    // MARK: 무한 스크롤 (종목 카드 세로 스크롤 → 그 종목 뉴스를 커서로 더 불러옴)

    /// 첫 페이지 이후 누적된 그 종목의 뉴스(브리핑의 primary/other 뒤에 이어 붙는다).
    func extraNews(for code: String) -> [NewsItem] { appendedNews[code] ?? [] }

    /// 그 종목에 더 불러올 뉴스가 있는지(로더 표시·트리거용).
    func hasMoreNews(for code: String) -> Bool { hasMoreByCode[code] ?? false }

    /// 그 종목의 더보기 요청이 진행 중인지.
    func isLoadingMore(for code: String) -> Bool { loadingMore.contains(code) }

    /// 다음 페이지를 불러와 누적한다. 더 없거나 진행 중이면 무시(중복 호출 방지).
    func loadMore(for code: String) async {
        guard hasMoreByCode[code] == true, !loadingMore.contains(code),
              let cursor = nextCursors[code] else { return }
        loadingMore.insert(code)
        defer { loadingMore.remove(code) }
        do {
            let page = try await news.fetchNewsPage(forStockCode: code, cursor: cursor)
            appendedNews[code, default: []].append(contentsOf: page.items)
            if let next = page.nextCursor { nextCursors[code] = next } else { nextCursors[code] = nil }
            hasMoreByCode[code] = page.hasNext
        } catch {
            // 실패 시 조용히 멈춘다(hasMore 유지 → 다음 스크롤에서 재시도 가능).
        }
    }

    /// 브리핑 결과로 종목별 페이지네이션 상태를 초기화한다(첫 페이지 = 브리핑, 커서는 그 다음부터).
    private func seedPagination(from briefing: DailyBriefing) {
        appendedNews.removeAll()
        nextCursors.removeAll()
        hasMoreByCode.removeAll()
        loadingMore.removeAll()
        for stock in briefing.stocks {
            hasMoreByCode[stock.id] = stock.hasMoreNews
            if let cursor = stock.newsCursor { nextCursors[stock.id] = cursor }
        }
    }

    /// 뉴스 상세 시트 표시.
    func openNewsDetail(stockName: String, news: NewsItem) {
        presentationCounter += 1
        presentedNews = PresentedNews(id: presentationCounter, stockName: stockName, news: news)
    }

    func dismissNewsDetail() {
        presentedNews = nil
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
            seedPagination(from: briefing)
            state = .loaded(briefing)
        } catch {
            state = .error("소식을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.")
        }
    }
}
