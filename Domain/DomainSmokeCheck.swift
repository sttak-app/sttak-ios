#if DEBUG
import Foundation

// 가벼운 컴파일 체크 — 각 도메인 타입을 한 번씩 생성해 초기자·필드가 맞는지 확인한다.
// (DEBUG 전용, 호출되지 않음. 동작 테스트는 이후 커밋에서 추가.)
private func _domainSmokeCheck() {
    // Value Objects
    _ = Sentiment.positive
    _ = Money.krw(10_000_000)
    _ = Money(amount: 100, currency: .usd)
    _ = Term(term: "잠정실적", definition: "정식 발표 전 대략적 실적")
    _ = NewsItem(
        sentiment: .positive,
        title: "2나노 파운드리 대형 고객 수주",
        easy: "최첨단 반도체 위탁생산을 큰 고객에게 따냈어요",
        summary: "파운드리 경쟁력과 미래 매출 기대가 커지는 소식이에요.",
        whyPoints: ["수주는 미래 매출로 이어져요"],
        reason: "대형 고객 확보로 긍정적이에요.",
        terms: [Term(term: "수주", definition: "계약을 따냈다는 뜻")],
        source: "전자공시·DART",
        publishedAt: Date(),
        originalURL: URL(string: "https://example.com"),
        lead: "삼성전자가 2나노 공정 기반 위탁생산 계약을 체결했다고 공시했다..."
    )
    _ = Quote(price: .krw(71_200), previousClose: .krw(70_000), changePercent: 1.78, sparkline: [68, 70, 71.2])
    _ = Candle(date: Date(), open: 70, high: 73, low: 69, close: 71.2, volume: 1_200_000)
    _ = IndicatorKind.rsi
    _ = ChartSignal(kind: .goldenCross, candleIndex: 42, subsequentDirection: .up)
    _ = QuizQuestion(
        question: "RSI 70 이상은 보통 무엇을 뜻하나요?",
        options: ["과매도", "과열", "횡보", "거래량 급증"],
        answerIndex: 1,
        explanation: "RSI 70↑은 단기 과열 구간으로 봅니다.",
        category: "차트·지표"
    )
    _ = TradeRationale(text: "뉴스가 긍정적으로 보여요")
    _ = Holding(stockCode: "005930", quantity: 10, averagePrice: .krw(70_000))
    _ = ChatMessage(role: .user, text: "이게 왜 중요한가요?", timestamp: Date())
    _ = RankingEntry(rank: 1, nickname: "투자초보", assetValue: .krw(12_300_000), rankChange: 2, isCurrentUser: false)
    _ = FollowUpRetrospective(evaluatedAt: Date(), priceAtFollowUp: .krw(75_000), comparisonText: "한 달 뒤 주가는 올랐어요.")

    // Entities
    _ = User(id: "u1", authProvider: .kakao, nickname: "투자초보", watchlistCodes: ["005930", "000660"])
    _ = Stock(code: "005930", name: "삼성전자", sector: "반도체", market: .kospi, currency: .krw)
    _ = Portfolio(cash: .krw(10_000_000), holdings: [
        Holding(stockCode: "005930", quantity: 10, averagePrice: .krw(70_000))
    ])
    let retro = Retrospective(
        id: "r1", summaryLine: "차분한 매도였어요", goodPoints: ["근거가 분명했어요"],
        watchPoints: ["분할 매도도 고려해보세요"], isPartialSell: false, createdAt: Date(), followUp: nil
    )
    _ = Trade(
        id: "t1", type: .sell, stockCode: "005930", quantity: 5, price: .krw(72_000),
        rationale: TradeRationale(text: "목표가 도달"), executedAt: Date(),
        realizedProfit: .krw(20_000), retrospective: retro
    )
    _ = ChatSession(id: "c1", context: .news, messages: [])
    _ = RankingSnapshot(id: "s1", entries: [], updatedAt: Date())
}
#endif
