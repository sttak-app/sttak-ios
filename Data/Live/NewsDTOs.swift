import Foundation

/// GET /api/v1/news?code=… 의 content(NewsFeedResponse) — 한 종목의 뉴스 카드 목록 + 커서 페이지네이션.
/// 공통 봉투 `{message, content}` 는 APIClient 가 언래핑하므로 여기서는 content 본문만 표현한다.
struct NewsFeedDTO: Decodable, Sendable {
    let items: [NewsItemDTO]
    let nextCursor: String?     // 다음 페이지 없으면 null
    let hasNext: Bool
}

/// GET /api/v1/news 응답의 뉴스 한 건(NewsCardResponse, items[] 의 원소).
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
