import Foundation

/// 한 종목 뉴스의 한 페이지 — 커서 기반 페이지네이션 결과.
/// 매핑: GET /api/v1/news?code=…&cursor=… 의 content(NewsFeedResponse).
struct NewsPage: Sendable, Equatable {
    let items: [NewsItem]
    let nextCursor: String?   // 다음 페이지가 없으면 nil
    let hasNext: Bool

    /// 뉴스가 없거나 조회 실패를 흡수할 때 쓰는 빈 페이지.
    static let empty = NewsPage(items: [], nextCursor: nil, hasNext: false)
}
