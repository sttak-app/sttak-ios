import Foundation

/// 시세·종목 Live. 시세/종목/검색/인기 종목·캔들은 서버, 기초정보(PER/PBR)는 서버 엔드포인트가 없어 Mock.
/// 시세·캔들은 서버가 빈 값을 주는 동안(data.go.kr 키 주입 전) Mock이 빈자리를 채운다(fetchQuotes·fetchCandles 참고).
struct LiveMarketDataRepository: MarketDataRepository {
    let api: APIClient
    /// 시세·캔들 공백 보충 + 기초정보(서버 엔드포인트 없음)용 폴백(현재 MockMarketDataRepository).
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

    // 표현 계층이 한 번 받은 시리즈를 로컬로 윈도잉(기간/줌/팬)하고 60·120일 이평선도 계산하므로,
    // 가장 넓은 기간(1Y)을 한 번에 받는다. period별 재요청은 하지 않는다(ChartLearningViewModel).
    func fetchCandles(forStockCode code: String) async throws -> [Candle] {
        let feed: CandleFeedDTO? = try? await api.request(
            .get("/api/v1/candles", query: [
                URLQueryItem(name: "code", value: code),
                URLQueryItem(name: "period", value: "1Y")
            ])
        )
        // 서버가 캔들을 주면 그대로(시간 오름차순 계약), 아직 빈 동안은 Mock이 채운다 → 서버 데이터 도착 시 자동 전환.
        if let candles = feed?.candles, !candles.isEmpty {
            return candles.map { $0.toDomain() }
        }
        return try await fallback.fetchCandles(forStockCode: code)
    }

    // MARK: 서버 엔드포인트 없음 — Mock 유지 (기초정보 PER/PBR/시총)

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
