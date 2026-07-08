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
        async let newsTask = news.fetchNews(forStockCodes: watchlistCodes)

        let stocks = try await stocksTask
        let quotes = try await quotesTask
        let newsByCode = try await newsTask

        // 관심종목 순서 유지.
        let ordered = watchlistCodes.compactMap { code in stocks.first { $0.code == code } }
        return Self.aggregate(orderedStocks: ordered, quotes: quotes, newsByCode: newsByCode)
    }

    /// 순수 집계(테스트 대상). 입력 감정 → 무드/우세감정/주목소식 정렬.
    static func aggregate(
        orderedStocks: [Stock],
        quotes: [String: Quote],
        newsByCode: [String: [NewsItem]]
    ) -> DailyBriefing {
        var totalPositive = 0, totalNeutral = 0, totalNegative = 0
        var briefings: [StockBriefing] = []

        for stock in orderedStocks {
            let items = newsByCode[stock.code] ?? []
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
                    primaryNews: Array(ranked.prefix(2)),
                    otherNews: Array(ranked.dropFirst(2))
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
