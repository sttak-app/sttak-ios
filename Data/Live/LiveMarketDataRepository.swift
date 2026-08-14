import Foundation

/// 시세·종목 Live. 시세/종목/검색/인기 종목·캔들은 서버.
/// Mock 폴백 없음 — 서버가 값을 주지 않으면 빈 값이 그대로 표현 계층으로 전달된다.
struct LiveMarketDataRepository: MarketDataRepository {
    let api: APIClient

    func fetchQuotes(forStockCodes codes: [String]) async throws -> [String: Quote] {
        guard !codes.isEmpty else { return [:] }
        let serverQuotes: [String: QuoteDTO] = try await api.request(
            .get("/api/v1/quotes", query: [URLQueryItem(name: "codes", value: codes.joined(separator: ","))])
        )
        return serverQuotes.mapValues { $0.toDomain() }
    }

    func fetchStocks(forCodes codes: [String]) async throws -> [Stock] {
        guard !codes.isEmpty else { return [] }
        let dtos: [StockDTO] = try await api.request(
            .get("/api/v1/stocks", query: [URLQueryItem(name: "codes", value: codes.joined(separator: ","))])
        )
        return dtos.map { $0.toDomain() }
    }

    func searchStocks(query: String) async throws -> [Stock] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        let dtos: [StockDTO] = try await api.request(
            .get("/api/v1/stocks/search", query: [URLQueryItem(name: "q", value: trimmed)])
        )
        return dtos.map { $0.toDomain() }
    }

    func fetchPopularStocks() async throws -> [Stock] {
        let dtos: [StockDTO] = try await api.request(.get("/api/v1/stocks/popular"))
        return dtos.map { $0.toDomain() }
    }

    // 표현 계층이 한 번 받은 시리즈를 로컬로 윈도잉(기간/줌/팬)하고 60·120일 이평선도 계산하므로,
    // 가장 넓은 기간(1Y)을 한 번에 받는다. period별 재요청은 하지 않는다(ChartLearningViewModel).
    func fetchCandles(forStockCode code: String) async throws -> [Candle] {
        let feed: CandleFeedDTO = try await api.request(
            .get("/api/v1/candles", query: [
                URLQueryItem(name: "code", value: code),
                URLQueryItem(name: "period", value: "1Y")
            ])
        )
        return feed.candles.map { $0.toDomain() }
    }

    // MARK: 서버 엔드포인트 없음 — 기초정보(PER/PBR/시총)는 아직 없음.

    func fetchFundamentals(forCode code: String) async throws -> StockFundamentals? {
        nil
    }

    #if DEBUG
    // Live 시세는 임의 조정 불가 — no-op.
    func debugNudgePrice(byPercent percent: Double, forStockCode code: String) async {}
    func debugResetPrices() async {}
    #endif
}
