import Foundation

/// 시세·종목 Live. 시세/종목/검색/인기 종목은 서버, 캔들·기초정보는 서버 미구현이라 Mock 폴백.
/// 시세도 서버가 빈 값을 주는 동안은 코드별로 Mock이 빈자리를 채운다(아래 fetchQuotes 참고).
struct LiveMarketDataRepository: MarketDataRepository {
    let api: APIClient
    /// 캔들·기초정보(서버 미구현) + 시세 공백 보충용 폴백(현재 MockMarketDataRepository).
    let fallback: any MarketDataRepository

    func fetchQuotes(forStockCodes codes: [String]) async throws -> [String: Quote] {
        guard !codes.isEmpty else { return [:] }
        let serverQuotes: [String: QuoteDTO] = (try? await api.request(
            .get("/api/v1/quotes", query: [URLQueryItem(name: "codes", value: codes.joined(separator: ","))])
        )) ?? [:]

        // 임시 폴백: 시세 수집 키(data.go.kr) 주입 전까지 서버 /quotes가 빈 map을 줄 수 있다.
        // 코드별 병합 — 서버 값이 있으면 서버 우선, 없는 코드는 Mock이 채운다(스파크라인 포함).
        // 서버가 데이터를 주기 시작하면 자동으로 Live 값으로 전환된다.
        var result = serverQuotes.mapValues { $0.toDomain() }
        let missing = codes.filter { result[$0] == nil }
        if !missing.isEmpty,
           let mockQuotes = try? await fallback.fetchQuotes(forStockCodes: missing) {
            result.merge(mockQuotes) { server, _ in server }
        }
        return result
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

    // MARK: 서버 미구현 — Mock 폴백 (candles·fundamentals 엔드포인트 확정 시 교체)

    func fetchCandles(forStockCode code: String) async throws -> [Candle] {
        try await fallback.fetchCandles(forStockCode: code)
    }

    func fetchFundamentals(forCode code: String) async throws -> StockFundamentals? {
        try await fallback.fetchFundamentals(forCode: code)
    }

    #if DEBUG
    func debugNudgePrice(byPercent percent: Double, forStockCode code: String) async {
        await fallback.debugNudgePrice(byPercent: percent, forStockCode: code)
    }

    func debugResetPrices() async {
        await fallback.debugResetPrices()
    }
    #endif
}
