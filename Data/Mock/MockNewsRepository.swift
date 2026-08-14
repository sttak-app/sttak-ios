import Foundation

/// 뉴스 Mock. sttak-data.js 뉴스를 가진 종목만 다룬다.
/// 커서 페이지네이션은 fixture 배열을 작은 페이지로 슬라이스해 흉내낸다(무한 스크롤 검증용).
/// cursor = 다음 페이지 시작 오프셋(문자열). nil이면 첫 페이지.
struct MockNewsRepository: NewsRepository {
    /// 픽스처가 몇 건 안 되므로 작게 잡아 두 페이지 이상 나오게 한다.
    private let pageSize = 2

    func fetchNewsPage(forStockCode code: String, cursor: String?) async throws -> NewsPage {
        let all = MockNewsFixtures.newsByCode()[code] ?? []
        let start = cursor.flatMap(Int.init) ?? 0
        guard start < all.count else { return .empty }
        let end = min(start + pageSize, all.count)
        let hasNext = end < all.count
        return NewsPage(
            items: Array(all[start..<end]),
            nextCursor: hasNext ? String(end) : nil,
            hasNext: hasNext
        )
    }
}
