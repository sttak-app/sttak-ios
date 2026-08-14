import XCTest
@testable import sttak

/// Live DTO → 도메인 매핑 — 감정 SCREAMING_SNAKE_CASE, 정수 KRW → Money, 1-based → 0-based 등.
final class LiveDTOMappingTests: XCTestCase {

    private let decoder = JSONCoding.decoder()

    // MARK: 뉴스

    func testNewsMapping_feedEnvelopeAndFields() throws {
        // 서버 실제 content(NewsFeedResponse): {items: [card], nextCursor, hasNext}. 봉투 {message, content}는 APIClient가 언래핑.
        let json = Data("""
        {
          "items": [{
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
          }],
          "nextCursor": "CURSOR123",
          "hasNext": true
        }
        """.utf8)
        let dto = try decoder.decode(NewsFeedDTO.self, from: json)
        XCTAssertEqual(dto.nextCursor, "CURSOR123")
        XCTAssertTrue(dto.hasNext)
        let item = try XCTUnwrap(dto.items.first).toDomain()
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
        {"items": [{"title": "제목만", "publishedAt": "2026-07-07T09:00:00Z"}], "nextCursor": null, "hasNext": false}
        """.utf8)
        let item = try XCTUnwrap(
            try decoder.decode(NewsFeedDTO.self, from: json).items.first
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

    // MARK: 매매 — 접수 응답(PENDING) + tradingDate는 LocalDate(오프셋 없음)

    func testCreateTradeMapping_pendingWithLocalDate() throws {
        let json = Data("""
        {"id": "42", "type": "BUY", "stockCode": "005930", "quantity": 10, "rationale": "근거",
         "status": "PENDING", "orderedAt": "2026-08-12T02:30:00Z", "tradingDate": "2026-08-13",
         "fillBasis": "OPEN", "referencePrice": 71200}
        """.utf8)
        let trade = try decoder.decode(CreateTradeResponseDTO.self, from: json).toDomain()
        XCTAssertEqual(trade.status, .pending)
        XCTAssertEqual(trade.fillBasis, .open)
        XCTAssertEqual(trade.referencePrice, .krw(71_200))
        XCTAssertNil(trade.filledPrice)
        XCTAssertNotNil(trade.tradingDate)   // LocalDate("2026-08-13")가 깨지지 않고 파싱됨
    }

    // MARK: 매매 — 거래내역(체결·거부 + 임베드 회고)

    func testTradeMapping_filledSellWithRetrospective() throws {
        let json = Data("""
        {"id": "7", "type": "SELL", "stockCode": "005930", "stockName": "삼성전자", "quantity": 5,
         "rationale": "목표 도달", "status": "FILLED", "tradingDate": "2026-08-10", "fillBasis": "CLOSE",
         "referencePrice": 70000, "filledPrice": 71200, "filledAt": "2026-08-10T06:00:00Z",
         "rejectedReason": null, "realizedProfit": 17000, "orderedAt": "2026-08-09T02:00:00Z",
         "retrospective": {"summaryLine": "5주 매도", "goodPoints": ["근거가 분명"], "watchPoints": ["분할도 고려"], "isPartialSell": true}}
        """.utf8)
        let trade = try decoder.decode(TradeDTO.self, from: json).toDomain()
        XCTAssertEqual(trade.type, .sell)
        XCTAssertEqual(trade.status, .filled)
        XCTAssertEqual(trade.fillBasis, .close)
        XCTAssertEqual(trade.filledPrice, .krw(71_200))
        XCTAssertEqual(trade.realizedProfit, .krw(17_000))
        XCTAssertEqual(trade.retrospective?.summaryLine, "5주 매도")
        XCTAssertEqual(trade.retrospective?.isPartialSell, true)
        XCTAssertNotNil(trade.filledAt)
    }

    func testTradeMapping_rejected() throws {
        let json = Data("""
        {"id": "8", "type": "BUY", "stockCode": "005930", "quantity": 3, "rationale": "근거",
         "status": "REJECTED", "tradingDate": "2026-08-10", "fillBasis": "OPEN", "referencePrice": 70000,
         "filledPrice": null, "filledAt": null, "rejectedReason": "현금 부족", "realizedProfit": null,
         "orderedAt": "2026-08-09T02:00:00Z", "retrospective": null}
        """.utf8)
        let trade = try decoder.decode(TradeDTO.self, from: json).toDomain()
        XCTAssertEqual(trade.status, .rejected)
        XCTAssertEqual(trade.rejectedReason, "현금 부족")
        XCTAssertNil(trade.retrospective)
    }

    // MARK: 포트폴리오

    func testPortfolioMapping_cashAndHoldings() throws {
        let json = Data("""
        {"cash": 8738000, "holdings": [
          {"stockCode": "005930", "stockName": "삼성전자", "quantity": 10, "averagePrice": 67800}]}
        """.utf8)
        let portfolio = try decoder.decode(PortfolioDTO.self, from: json).toDomain()
        XCTAssertEqual(portfolio.cash, .krw(8_738_000))
        XCTAssertEqual(portfolio.holdings.first?.stockCode, "005930")
        XCTAssertEqual(portfolio.holdings.first?.averagePrice, .krw(67_800))
    }

    // MARK: 랭킹 — updatedAt은 LocalDateTime(오프셋 없음) + 내 순위

    func testRankingMapping_localDateTimeUpdatedAt() throws {
        let json = Data("""
        {"updatedAt": "2026-08-12T16:20:09", "entries": [
          {"rank": 1, "nickname": "우상향중", "assetValue": 16420000, "profitRate": 64.2}]}
        """.utf8)
        let snapshot = try decoder.decode(RankingSnapshotDTO.self, from: json).toDomain()
        // 오프셋 없는 updatedAt이 디코딩을 깨뜨리지 않고 엔트리가 매핑된다.
        XCTAssertEqual(snapshot.entries.first?.rank, 1)
        XCTAssertEqual(snapshot.entries.first?.assetValue, .krw(16_420_000))
        XCTAssertEqual(snapshot.entries.first?.rankChange, 0)   // 서버 미제공 → 0
    }

    func testMyRankingMapping() throws {
        let json = Data("""
        {"rank": 12, "assetValue": 12940000, "totalCount": 100, "topPercent": 12, "profitRate": 29.4}
        """.utf8)
        let mine = try decoder.decode(MyRankingDTO.self, from: json).toDomain()
        XCTAssertEqual(mine.rank, 12)
        XCTAssertEqual(mine.assetValue, .krw(12_940_000))
        XCTAssertEqual(mine.topPercent, 12)
    }
}
