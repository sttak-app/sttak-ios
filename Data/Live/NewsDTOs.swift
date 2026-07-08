import Foundation

/// GET /api/v1/news 응답 본문 — 서버는 코드별 map 을 feed/fetchedAt 엔벨로프로 감싼다(NewsFeedResponse).
struct NewsFeedDTO: Decodable, Sendable {
    let feed: [String: [NewsItemDTO]]
    let fetchedAt: Date?
}

/// GET /api/v1/news 응답의 뉴스 한 건(feed 맵의 원소).
struct NewsItemDTO: Decodable, Sendable {
    let sentiment: String?         // "POSITIVE" | "NEUTRAL" | "NEGATIVE" (미분류 시 null 가능 — 중립 처리)
    let title: String
    let easy: String?
    let summary: String?
    let whyPoints: [String]?
    let reason: String?
    let terms: [TermDTO]?
    let source: String?
    let publishedAt: Date
    let originalURL: String?
    let lead: String?              // 원문 lead 는 수집 소스에 따라 없을 수 있다

    func toDomain() -> NewsItem {
        NewsItem(
            sentiment: Self.sentiment(from: sentiment ?? ""),
            title: title,
            easy: easy ?? "",
            summary: summary ?? "",
            whyPoints: whyPoints ?? [],
            reason: reason ?? "",
            terms: (terms ?? []).map { $0.toDomain() },
            source: source ?? "",
            publishedAt: publishedAt,
            originalURL: originalURL.flatMap(URL.init(string:)),
            lead: lead ?? ""
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
