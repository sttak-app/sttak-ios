import Foundation

/// 분류된 뉴스. 관심종목들의 뉴스를 한 번에(배치) 받아 홈 브리핑 합성에 쓴다.
/// 매핑: GET /news?codes=…  → 종목코드별 뉴스 목록.
protocol NewsRepository: Sendable {
    /// 여러 종목의 분류된 뉴스를 한 번에 가져온다. 키=종목코드.
    func fetchNews(forStockCodes codes: [String]) async throws -> [String: [NewsItem]]
}
