import Foundation

/// 시세·종목 데이터(백엔드가 KIS 프록시). 키는 서버에만.
/// 매핑: quotes=GET /quotes?codes=…, candles=GET /candles?code=…,
///       stocks=GET /stocks?codes=…, search=GET /stocks/search?q=…
protocol MarketDataRepository: Sendable {
    /// 여러 종목의 실시간 시세를 한 번에. 키=종목코드.
    func fetchQuotes(forStockCodes codes: [String]) async throws -> [String: Quote]
    /// 한 종목의 캔들 시계열(차트용). 기간/줌은 표현 계층에서 윈도잉한다.
    func fetchCandles(forStockCode code: String) async throws -> [Candle]
    /// 종목 메타 정보.
    func fetchStocks(forCodes codes: [String]) async throws -> [Stock]
    /// 온보딩 검색(종목명 공백무시/코드 prefix 매칭).
    func searchStocks(query: String) async throws -> [Stock]
    /// 인기 종목(온보딩 추천). 매핑: GET /stocks/popular.
    func fetchPopularStocks() async throws -> [Stock]
    /// 종목 기초 정보(시총/PER/PBR). 없으면 nil. 매핑: GET /stocks/{code}/fundamentals.
    func fetchFundamentals(forCode code: String) async throws -> StockFundamentals?
}
