import XCTest
@testable import sttak

/// LoadDailyBriefing 집계(순수 함수) 테스트 — 감정 입력 → 기대 무드/우세감정/정렬.
/// 프로토타입 규칙 기준, 손으로 기대값을 정함(자기참조 금지).
final class LoadDailyBriefingTests: XCTestCase {

    private func stock(_ code: String) -> Stock {
        Stock(code: code, name: "종목\(code)", sector: "", market: .kospi, currency: .krw)
    }

    private func news(_ sentiment: Sentiment, minutesAgo: Int, title: String = "t") -> NewsItem {
        NewsItem(
            sentiment: sentiment, title: title, easy: "e", summary: "s", whyPoints: [], reason: "r",
            terms: [], source: "src",
            publishedAt: Date(timeIntervalSince1970: 1_000_000 - Double(minutesAgo) * 60),
            originalURL: nil, lead: "l"
        )
    }

    /// 코드별 뉴스 배열을 aggregate 입력(단일 페이지, 더보기 없음)으로 감싼다.
    private func pages(_ byCode: [String: [NewsItem]]) -> [String: NewsPage] {
        byCode.mapValues { NewsPage(items: $0, nextCursor: nil, hasNext: false) }
    }

    // MARK: 전체 무드 (호재>악재=긍정 / 악재>호재=주의 / 동률=혼재)

    func testMood_positive_whenMorePositiveThanNegative() {
        let briefing = LoadDailyBriefing.aggregate(
            orderedStocks: [stock("A")],
            quotes: [:],
            pagesByCode: pages(["A": [news(.positive, minutesAgo: 1), news(.positive, minutesAgo: 2), news(.negative, minutesAgo: 3)]])
        )
        XCTAssertEqual(briefing.mood, .positive)
        XCTAssertEqual(briefing.breakdown.positive, 2)
        XCTAssertEqual(briefing.breakdown.negative, 1)
        XCTAssertEqual(briefing.totalNewsCount, 3)
    }

    func testMood_cautious_whenMoreNegative() {
        let briefing = LoadDailyBriefing.aggregate(
            orderedStocks: [stock("A")],
            quotes: [:],
            pagesByCode: pages(["A": [news(.negative, minutesAgo: 1), news(.negative, minutesAgo: 2), news(.positive, minutesAgo: 3)]])
        )
        XCTAssertEqual(briefing.mood, .cautious)
    }

    func testMood_mixed_whenTied() {
        let briefing = LoadDailyBriefing.aggregate(
            orderedStocks: [stock("A")],
            quotes: [:],
            pagesByCode: pages(["A": [news(.positive, minutesAgo: 1), news(.negative, minutesAgo: 2), news(.neutral, minutesAgo: 3)]])
        )
        XCTAssertEqual(briefing.mood, .mixed)
    }

    // MARK: 종목별 우세 감정 (스트립 점)

    func testDominantSentiment_perStock() {
        let briefing = LoadDailyBriefing.aggregate(
            orderedStocks: [stock("A"), stock("B")],
            quotes: [:],
            pagesByCode: pages([
                "A": [news(.positive, minutesAgo: 1), news(.positive, minutesAgo: 2), news(.negative, minutesAgo: 3)], // 호재 우세
                "B": [news(.negative, minutesAgo: 1), news(.neutral, minutesAgo: 2)],                                  // 악재 우세
            ])
        )
        XCTAssertEqual(briefing.stocks[0].dominantSentiment, .positive)
        XCTAssertEqual(briefing.stocks[1].dominantSentiment, .negative)
    }

    func testDominantSentiment_neutralWhenTied() {
        let briefing = LoadDailyBriefing.aggregate(
            orderedStocks: [stock("A")],
            quotes: [:],
            pagesByCode: pages(["A": [news(.positive, minutesAgo: 1), news(.negative, minutesAgo: 2)]])
        )
        XCTAssertEqual(briefing.stocks[0].dominantSentiment, .neutral)
    }

    // MARK: 뉴스 정렬 (비중립 우선 → 최신순)

    func testNews_ranksNonNeutralFirstThenRecent() {
        // 중립(가장 최신) + 호재(오래됨) + 악재(중간) → 비중립이 먼저, 그중 최신(악재 3분 vs 호재 10분), 중립은 뒤로
        let items = [
            news(.neutral, minutesAgo: 1, title: "중립-최신"),
            news(.positive, minutesAgo: 10, title: "호재-오래"),
            news(.negative, minutesAgo: 3, title: "악재-중간"),
        ]
        let briefing = LoadDailyBriefing.aggregate(orderedStocks: [stock("A")], quotes: [:], pagesByCode: pages(["A": items]))
        let ordered = briefing.stocks[0].news
        XCTAssertEqual(ordered.map(\.title), ["악재-중간", "호재-오래", "중립-최신"])
    }

    // MARK: 무한 스크롤 커서 (첫 페이지 nextCursor/hasNext → StockBriefing 전달)

    func testNewsCursor_isCarriedIntoBriefing() {
        let briefing = LoadDailyBriefing.aggregate(
            orderedStocks: [stock("A"), stock("B")],
            quotes: [:],
            pagesByCode: [
                "A": NewsPage(items: [news(.positive, minutesAgo: 1)], nextCursor: "2", hasNext: true),
                "B": NewsPage(items: [news(.neutral, minutesAgo: 1)], nextCursor: nil, hasNext: false),
            ]
        )
        XCTAssertEqual(briefing.stocks[0].newsCursor, "2")
        XCTAssertTrue(briefing.stocks[0].hasMoreNews)
        XCTAssertNil(briefing.stocks[1].newsCursor)
        XCTAssertFalse(briefing.stocks[1].hasMoreNews)
    }

    // MARK: 빈/순서

    func testEmptyWatchlist_returnsEmptyBriefing() {
        let briefing = LoadDailyBriefing.aggregate(orderedStocks: [], quotes: [:], pagesByCode: [:])
        XCTAssertEqual(briefing.mood, .mixed)
        XCTAssertEqual(briefing.totalNewsCount, 0)
        XCTAssertTrue(briefing.stocks.isEmpty)
    }

    func testStockOrder_preservesInput() {
        let briefing = LoadDailyBriefing.aggregate(
            orderedStocks: [stock("C"), stock("A"), stock("B")],
            quotes: [:],
            pagesByCode: [:]
        )
        XCTAssertEqual(briefing.stocks.map(\.stock.code), ["C", "A", "B"])
    }
}
