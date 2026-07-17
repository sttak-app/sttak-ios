import XCTest
@testable import sttak

/// Live DTO → 도메인 매핑 — 감정 SCREAMING_SNAKE_CASE, 정수 KRW → Money, 1-based → 0-based 등.
final class LiveDTOMappingTests: XCTestCase {

    private let decoder = JSONCoding.decoder()

    // MARK: 뉴스

    func testNewsMapping_feedEnvelopeAndFields() throws {
        // 서버 실제 응답 형태: {feed: {code: [item]}, fetchedAt} 엔벨로프 (NewsFeedResponse)
        let json = Data("""
        {
          "feed": {
            "005930": [{
              "sentiment": "POSITIVE",
              "title": "실적 개선",
              "easy": "쉽게 말하면 좋아요",
              "summary": "요약",
              "whyPoints": ["포인트1", "포인트2"],
              "reason": "이유",
              "terms": [{"term": "PER", "definition": "주가수익비율"}],
              "source": "연합뉴스",
              "publishedAt": "2026-07-07T09:00:00Z",
              "originalURL": "https://news.example.com/1",
              "lead": "리드 문장"
            }]
          },
          "fetchedAt": "2026-07-08T14:00:00Z"
        }
        """.utf8)
        let dto = try decoder.decode(NewsFeedDTO.self, from: json)
        let item = try XCTUnwrap(dto.feed["005930"]?.first).toDomain()
        XCTAssertEqual(item.sentiment, .positive)
        XCTAssertEqual(item.title, "실적 개선")
        XCTAssertEqual(item.whyPoints.count, 2)
        XCTAssertEqual(item.terms.first?.term, "PER")
        XCTAssertEqual(item.terms.first?.definition, "주가수익비율")
        XCTAssertEqual(item.originalURL?.absoluteString, "https://news.example.com/1")
    }

    func testNewsMapping_missingOptionalFieldsAreDefaulted() throws {
        // lead/terms/whyPoints 등이 없어도(수집 소스에 따라 null) 디코딩이 깨지지 않는다.
        let json = Data("""
        {"feed": {"005930": [{"title": "제목만", "publishedAt": "2026-07-07T09:00:00Z"}]}}
        """.utf8)
        let item = try XCTUnwrap(
            try decoder.decode(NewsFeedDTO.self, from: json).feed["005930"]?.first
        ).toDomain()
        XCTAssertEqual(item.sentiment, .neutral)
        XCTAssertEqual(item.lead, "")
        XCTAssertTrue(item.terms.isEmpty)
    }

    func testNewsSentiment_mapping() {
        XCTAssertEqual(NewsItemDTO.sentiment(from: "POSITIVE"), .positive)
        XCTAssertEqual(NewsItemDTO.sentiment(from: "NEUTRAL"), .neutral)
        XCTAssertEqual(NewsItemDTO.sentiment(from: "NEGATIVE"), .negative)
        // 미지의 값은 중립으로 관대하게.
        XCTAssertEqual(NewsItemDTO.sentiment(from: "SOMETHING_NEW"), .neutral)
    }

    // MARK: 시세/종목

    func testQuoteMapping_intKRWAndSparkline() throws {
        let json = Data("""
        {"price": 71200, "previousClose": 70000, "changePercent": 1.71, "sparkline": [70000, 70500, 71200]}
        """.utf8)
        let quote = try decoder.decode(QuoteDTO.self, from: json).toDomain()
        XCTAssertEqual(quote.price, .krw(71_200))
        XCTAssertEqual(quote.previousClose, .krw(70_000))
        XCTAssertEqual(quote.changePercent, 1.71, accuracy: 0.0001)
        XCTAssertEqual(quote.sparkline, [70_000, 70_500, 71_200])
    }

    func testStockMapping_marketAndCurrency() throws {
        let json = Data("""
        [{"code": "005930", "name": "삼성전자", "sector": "반도체", "market": "KOSPI", "currency": "KRW"},
         {"code": "035720", "name": "카카오", "sector": "플랫폼", "market": "KOSDAQ", "currency": "KRW"}]
        """.utf8)
        let stocks = try decoder.decode([StockDTO].self, from: json).map { $0.toDomain() }
        XCTAssertEqual(stocks[0].market, .kospi)
        XCTAssertEqual(stocks[1].market, .kosdaq)
        XCTAssertEqual(stocks[0].currency, .krw)
        XCTAssertEqual(stocks[0].id, "005930")
    }

    // MARK: 퀴즈 (서버 1-based → 도메인 0-based)

    func testQuizNextMapping_question() throws {
        let json = Data("""
        {"cooldown": false,
         "question": {"quizId": 17, "question": "골든크로스란?", "options": ["a","b","c","d"]},
         "answeredInCycle": 1, "totalInCycle": 3, "nextAvailableAt": null}
        """.utf8)
        let state = try decoder.decode(QuizNextDTO.self, from: json).toDomain()
        guard case let .question(pending, answered, total) = state else {
            return XCTFail("question 상태를 기대")
        }
        XCTAssertEqual(pending.id, "17")
        XCTAssertEqual(pending.options.count, 4)
        XCTAssertNil(pending.category)
        XCTAssertEqual(answered, 1)
        XCTAssertEqual(total, 3)
    }

    func testQuizNextMapping_cooldown() throws {
        let json = Data("""
        {"cooldown": true, "question": null, "answeredInCycle": 3, "totalInCycle": 3,
         "nextAvailableAt": "2026-07-07T15:00:00Z"}
        """.utf8)
        let state = try decoder.decode(QuizNextDTO.self, from: json).toDomain()
        guard case let .cooldown(nextAt) = state else {
            return XCTFail("cooldown 상태를 기대")
        }
        XCTAssertNotNil(nextAt)
    }

    func testQuizSubmitMapping_oneBasedChoices() throws {
        let json = Data("""
        {"quizId": 17, "selectedChoice": 2, "correctChoice": 1, "isCorrect": false,
         "explanation": "해설", "earnedCapital": 0, "answeredInCycle": 2, "totalInCycle": 3,
         "completed": false, "nextAvailableAt": null}
        """.utf8)
        let result = try decoder.decode(QuizSubmitResponseDTO.self, from: json).toDomain()
        XCTAssertEqual(result.selectedIndex, 1)   // 2 → 1 (0-based)
        XCTAssertEqual(result.correctIndex, 0)    // 1 → 0
        XCTAssertFalse(result.isCorrect)
        XCTAssertEqual(result.earnedCapital, .krw(0))
        XCTAssertFalse(result.completed)
    }

    // MARK: 사용자

    func testUserMapping_provider() throws {
        let json = Data("""
        {"id": "u-1", "nickname": "투자초보", "authProvider": "KAKAO", "watchlistCodes": ["005930", "000660"]}
        """.utf8)
        let user = try decoder.decode(UserDTO.self, from: json).toDomain()
        XCTAssertEqual(user.authProvider, .kakao)
        XCTAssertEqual(user.watchlistCodes, ["005930", "000660"])
    }
}
