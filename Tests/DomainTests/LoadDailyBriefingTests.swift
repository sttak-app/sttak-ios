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

    // MARK: 전체 무드 (호재>악재=긍정 / 악재>호재=주의 / 동률=혼재)

    func testMood_positive_whenMorePositiveThanNegative() {
        let briefing = LoadDailyBriefing.aggregate(
            orderedStocks: [stock("A")],
            quotes: [:],
            newsByCode: ["A": [news(.positive, minutesAgo: 1), news(.positive, minutesAgo: 2), news(.negative, minutesAgo: 3)]]
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
            newsByCode: ["A": [news(.negative, minutesAgo: 1), news(.negative, minutesAgo: 2), news(.positive, minutesAgo: 3)]]
        )
        XCTAssertEqual(briefing.mood, .cautious)
    }

    func testMood_mixed_whenTied() {
        let briefing = LoadDailyBriefing.aggregate(
            orderedStocks: [stock("A")],
            quotes: [:],
            newsByCode: ["A": [news(.positive, minutesAgo: 1), news(.negative, minutesAgo: 2), news(.neutral, minutesAgo: 3)]]
        )
        XCTAssertEqual(briefing.mood, .mixed)
    }

    // MARK: 종목별 우세 감정 (스트립 점)

    func testDominantSentiment_perStock() {
        let briefing = LoadDailyBriefing.aggregate(
            orderedStocks: [stock("A"), stock("B")],
            quotes: [:],
            newsByCode: [
                "A": [news(.positive, minutesAgo: 1), news(.positive, minutesAgo: 2), news(.negative, minutesAgo: 3)], // 호재 우세
                "B": [news(.negative, minutesAgo: 1), news(.neutral, minutesAgo: 2)],                                  // 악재 우세
            ]
        )
        XCTAssertEqual(briefing.stocks[0].dominantSentiment, .positive)
        XCTAssertEqual(briefing.stocks[1].dominantSentiment, .negative)
    }

    func testDominantSentiment_neutralWhenTied() {
        let briefing = LoadDailyBriefing.aggregate(
            orderedStocks: [stock("A")],
            quotes: [:],
            newsByCode: ["A": [news(.positive, minutesAgo: 1), news(.negative, minutesAgo: 2)]]
        )
        XCTAssertEqual(briefing.stocks[0].dominantSentiment, .neutral)
    }

    // MARK: 주목 소식 정렬 (비중립 우선 → 최신순), 상위 2건

    func testPrimaryNews_ranksNonNeutralFirstThenRecent() {
        // 중립(가장 최신) + 호재(오래됨) + 악재(중간) → 비중립이 먼저, 그중 최신(악재 3분 vs 호재 10분)
        let items = [
            news(.neutral, minutesAgo: 1, title: "중립-최신"),
            news(.positive, minutesAgo: 10, title: "호재-오래"),
            news(.negative, minutesAgo: 3, title: "악재-중간"),
        ]
        let briefing = LoadDailyBriefing.aggregate(orderedStocks: [stock("A")], quotes: [:], newsByCode: ["A": items])
        let primary = briefing.stocks[0].primaryNews
        XCTAssertEqual(primary.count, 2)
        XCTAssertEqual(primary[0].title, "악재-중간")   // 비중립 + 더 최신
        XCTAssertEqual(primary[1].title, "호재-오래")   // 비중립
        XCTAssertEqual(briefing.stocks[0].otherNews.first?.title, "중립-최신") // 중립은 뒤로
    }

    // MARK: 빈/순서

    func testEmptyWatchlist_returnsEmptyBriefing() {
        let briefing = LoadDailyBriefing.aggregate(orderedStocks: [], quotes: [:], newsByCode: [:])
        XCTAssertEqual(briefing.mood, .mixed)
        XCTAssertEqual(briefing.totalNewsCount, 0)
        XCTAssertTrue(briefing.stocks.isEmpty)
    }

    func testStockOrder_preservesInput() {
        let briefing = LoadDailyBriefing.aggregate(
            orderedStocks: [stock("C"), stock("A"), stock("B")],
            quotes: [:],
            newsByCode: [:]
        )
        XCTAssertEqual(briefing.stocks.map(\.stock.code), ["C", "A", "B"])
    }
}
