import Foundation

/// 뉴스 Live: GET /api/v1/news?code=…&cursor=… → 한 종목의 분류 뉴스 한 페이지(NewsFeedResponse).
/// 공통 봉투 `{message, content}` 는 APIClient 가 언래핑하므로 여기서는 content(items/nextCursor/hasNext)만 매핑한다.
struct LiveNewsRepository: NewsRepository {
    let api: APIClient

    func fetchNewsPage(forStockCode code: String, cursor: String?) async throws -> NewsPage {
        var query = [URLQueryItem(name: "code", value: code)]
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        let dto: NewsFeedDTO = try await api.request(.get("/api/v1/news", query: query))
        return NewsPage(
            items: dto.items.map { $0.toDomain() },
            nextCursor: dto.nextCursor,
            hasNext: dto.hasNext
        )
    }
}
