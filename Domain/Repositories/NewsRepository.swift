import Foundation

/// 분류된 뉴스. 서버는 종목 하나씩 커서 페이지로 내려준다(NewsFeedResponse).
/// 매핑: GET /api/v1/news?code=…&cursor=…  → 한 종목의 뉴스 한 페이지.
/// 관심종목 배치(홈 브리핑)는 UseCase(LoadDailyBriefing)에서 코드별로 동시 호출해 합친다.
protocol NewsRepository: Sendable {
    /// 한 종목의 분류된 뉴스를 커서 페이지 단위로 가져온다. cursor=nil이면 첫 페이지.
    func fetchNewsPage(forStockCode code: String, cursor: String?) async throws -> NewsPage
}
