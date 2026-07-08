import Foundation

/// 뉴스 Live: GET /api/v1/news?codes=… → 코드별 분류 뉴스 목록.
struct LiveNewsRepository: NewsRepository {
    let api: APIClient

    func fetchNews(forStockCodes codes: [String]) async throws -> [String: [NewsItem]] {
        guard !codes.isEmpty else { return [:] }
        // 서버 응답은 {feed, fetchedAt} 엔벨로프(NewsFeedResponse) — feed 만 도메인으로 매핑한다.
        let dto: NewsFeedDTO = try await api.request(
            .get("/api/v1/news", query: [URLQueryItem(name: "codes", value: codes.joined(separator: ","))])
        )
        return dto.feed.mapValues { items in items.map { $0.toDomain() } }
    }
}
