import Foundation

/// GET /api/v1/news 응답의 뉴스 한 건(코드별 map의 원소).
struct NewsItemDTO: Decodable, Sendable {
    let sentiment: String          // "POSITIVE" | "NEUTRAL" | "NEGATIVE"
    let title: String
    let easy: String
    let summary: String
    let whyPoints: [String]
    let reason: String
    let terms: [TermDTO]
    let source: String
    let publishedAt: Date
    let originalURL: String?
    let lead: String

    func toDomain() -> NewsItem {
        NewsItem(
            sentiment: Self.sentiment(from: sentiment),
            title: title,
            easy: easy,
            summary: summary,
            whyPoints: whyPoints,
            reason: reason,
            terms: terms.map { $0.toDomain() },
            source: source,
            publishedAt: publishedAt,
            originalURL: originalURL.flatMap(URL.init(string:)),
            lead: lead
        )
    }

    static func sentiment(from raw: String) -> Sentiment {
        switch raw.uppercased() {
        case "POSITIVE": return .positive
        case "NEGATIVE": return .negative
        default: return .neutral // 미지의 값은 중립으로(판단을 단정하지 않는 톤과 일치)
        }
    }
}

struct TermDTO: Decodable, Sendable {
    let term: String
    let definition: String

    func toDomain() -> Term {
        Term(term: term, definition: definition)
    }
}
