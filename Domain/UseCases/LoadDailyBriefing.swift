import Foundation

/// ★ 홈 "3초 브리핑" 구성. 관심종목의 배치 시세(MarketData) + 분류된 뉴스(News)를 모아
/// 전체 무드·종목 스트립·포커스 카드 데이터를 합성한다.
/// 집계 규칙은 프로토타입 `sttak Home.dc.html` renderVals 와 동일하게 고정하고, 순수 함수
/// `aggregate`로 분리해 테스트 가능하게 한다.
struct LoadDailyBriefing: Sendable {
    let marketData: MarketDataRepository
    let news: NewsRepository

    func callAsFunction(watchlistCodes: [String]) async throws -> DailyBriefing {
        guard !watchlistCodes.isEmpty else {
            return DailyBriefing(
                mood: .mixed,
                breakdown: SentimentBreakdown(positive: 0, neutral: 0, negative: 0),
                totalNewsCount: 0,
                stocks: []
            )
        }
        async let stocksTask = marketData.fetchStocks(forCodes: watchlistCodes)
        async let quotesTask = marketData.fetchQuotes(forStockCodes: watchlistCodes)
        async let pagesTask = fetchFirstPages(codes: watchlistCodes)

        let stocks = try await stocksTask
        let quotes = try await quotesTask
        let pagesByCode = try await pagesTask

        // 관심종목 순서 유지.
        let ordered = watchlistCodes.compactMap { code in stocks.first { $0.code == code } }
        return Self.aggregate(orderedStocks: ordered, quotes: quotes, pagesByCode: pagesByCode)
    }

    /// 관심종목의 뉴스 첫 페이지를 코드별로 동시에 가져온다(서버는 종목 하나씩만 조회).
    /// 한 종목 조회가 실패/무뉴스여도 브리핑 전체가 깨지지 않도록 빈 페이지로 흡수한다.
    private func fetchFirstPages(codes: [String]) async throws -> [String: NewsPage] {
        try await withThrowingTaskGroup(of: (String, NewsPage).self) { group in
            for code in codes {
                group.addTask {
                    let page = (try? await news.fetchNewsPage(forStockCode: code, cursor: nil)) ?? .empty
                    return (code, page)
                }
            }
            var result: [String: NewsPage] = [:]
            for try await (code, page) in group { result[code] = page }
            return result
        }
    }

    /// 순수 집계(테스트 대상). 입력 감정 → 무드/우세감정/주목소식 정렬 + 첫 페이지 커서 전달.
    static func aggregate(
        orderedStocks: [Stock],
        quotes: [String: Quote],
        pagesByCode: [String: NewsPage]
    ) -> DailyBriefing {
        var totalPositive = 0, totalNeutral = 0, totalNegative = 0
        var briefings: [StockBriefing] = []

        for stock in orderedStocks {
            let page = pagesByCode[stock.code] ?? .empty
            let items = page.items
            var positive = 0, neutral = 0, negative = 0
            for item in items {
                switch item.sentiment {
                case .positive: positive += 1
                case .neutral: neutral += 1
                case .negative: negative += 1
                }
            }
            totalPositive += positive
            totalNeutral += neutral
            totalNegative += negative

            let dominant: Sentiment = positive > negative ? .positive : (negative > positive ? .negative : .neutral)
            let ranked = rankByImportance(items)

            briefings.append(
                StockBriefing(
                    stock: stock,
                    quote: quotes[stock.code],
                    dominantSentiment: dominant,
                    news: ranked,
                    newsCursor: page.nextCursor,
                    hasMoreNews: page.hasNext
                )
            )
        }

        let mood: BriefingMood = totalPositive > totalNegative
            ? .positive
            : (totalNegative > totalPositive ? .cautious : .mixed)
        let breakdown = SentimentBreakdown(positive: totalPositive, neutral: totalNeutral, negative: totalNegative)

        return DailyBriefing(mood: mood, breakdown: breakdown, totalNewsCount: breakdown.total, stocks: briefings)
    }

    /// 중요도 정렬: 비중립(호재/악재) 우선 → 최신순.
    private static func rankByImportance(_ items: [NewsItem]) -> [NewsItem] {
        items.enumerated().sorted { lhs, rhs in
            let lw = lhs.element.sentiment == .neutral ? 0 : 1
            let rw = rhs.element.sentiment == .neutral ? 0 : 1
            if lw != rw { return lw > rw }
            return lhs.element.publishedAt > rhs.element.publishedAt // 최신 먼저
        }.map(\.element)
    }
}
