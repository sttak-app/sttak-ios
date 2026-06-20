import Foundation

/// 뉴스 Mock. sttak-data.js 뉴스를 가진 종목(3개)만 결과에 담는다.
struct MockNewsRepository: NewsRepository {
    func fetchNews(forStockCodes codes: [String]) async throws -> [String: [NewsItem]] {
        let all = MockNewsFixtures.newsByCode()
        var result: [String: [NewsItem]] = [:]
        for code in codes {
            if let news = all[code] { result[code] = news }
        }
        return result
    }
}
