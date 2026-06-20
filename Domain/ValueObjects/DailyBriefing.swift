import Foundation

/// 홈 브리핑 전체 무드(관심종목 뉴스 감정 집계 결과).
enum BriefingMood: Sendable, Equatable {
    case positive   // 호재 우세 — "대체로 긍정적"
    case cautious   // 악재 우세 — "조심해서 볼 소식"
    case mixed      // 동률/혼재 — "섞여 있는 하루"
}

/// 감정 집계(무드 바). 비율(%)은 표현 계층에서 total로 계산한다.
struct SentimentBreakdown: Sendable, Equatable {
    let positive: Int  // 호재
    let neutral: Int    // 중립
    let negative: Int   // 악재
    var total: Int { positive + neutral + negative }
}

/// 한 종목의 홈 다이제스트(포커스 카드 1장).
struct StockBriefing: Sendable, Equatable, Identifiable {
    let stock: Stock
    let quote: Quote?
    let dominantSentiment: Sentiment   // 스트립 점 색
    let primaryNews: [NewsItem]        // 주목 소식(≤2)
    let otherNews: [NewsItem]          // 그 외 소식
    var id: String { stock.code }
}

/// 홈 브리핑 전체.
struct DailyBriefing: Sendable, Equatable {
    let mood: BriefingMood
    let breakdown: SentimentBreakdown   // 전체 무드 바
    let totalNewsCount: Int
    let stocks: [StockBriefing]
}
