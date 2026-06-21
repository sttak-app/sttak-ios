import Foundation

/// 시세·종목 Mock. 시세는 sttak-data 오버라이드 + Prototype 유니버스, 캔들은 결정적 생성.
struct MockMarketDataRepository: MarketDataRepository {
    /// DEBUG 시세 오프셋을 공유하기 위한 store. (release에선 오프셋 적용 안 함)
    let store: MockLocalStore

    func fetchQuotes(forStockCodes codes: [String]) async throws -> [String: Quote] {
        var result: [String: Quote] = [:]
        for code in codes {
            guard var quote = Self.quote(for: code) else { continue }
            #if DEBUG
            let offset = await store.debugPriceOffset(for: code)
            if offset != 0 { quote = quote.adjusted(byOffset: offset) }
            #endif
            result[code] = quote
        }
        return result
    }

    #if DEBUG
    /// 차트 디버그: 현재가를 ±% 만큼 누적 조정(이익/손실 회고·자산요약 검증). 시세 레이어에 반영.
    func debugNudgePrice(byPercent percent: Double, forStockCode code: String) async {
        guard let base = Self.quote(for: code)?.price.amount else { return }
        await store.debugAddPriceOffset(Int((Double(base) * percent / 100).rounded()), for: code)
    }
    func debugResetPrices() async { await store.clearDebugPriceOffsets() }
    #endif

    func fetchCandles(forStockCode code: String) async throws -> [Candle] {
        guard let seed = MockData.candleSeeds[code] else {
            throw RepositoryError.notFound
        }
        return CandleGenerator.candles(seed: seed.seed, base: seed.base, finalPrice: seed.price)
    }

    func fetchStocks(forCodes codes: [String]) async throws -> [Stock] {
        let set = Set(codes)
        return MockData.stocks.filter { set.contains($0.code) }
    }

    func searchStocks(query: String) async throws -> [Stock] {
        let trimmed = query.replacingOccurrences(of: " ", with: "")
        guard !trimmed.isEmpty else { return [] }
        let matches = MockData.stocks.filter { stock in
            stock.name.replacingOccurrences(of: " ", with: "").localizedCaseInsensitiveContains(trimmed)
                || stock.code.hasPrefix(trimmed)
        }
        return Array(matches.prefix(8))
    }

    func fetchPopularStocks() async throws -> [Stock] {
        let byCode = Dictionary(uniqueKeysWithValues: MockData.stocks.map { ($0.code, $0) })
        return MockData.popularCodes.compactMap { byCode[$0] }
    }

    func fetchFundamentals(forCode code: String) async throws -> StockFundamentals? {
        MockData.fundamentals[code]
    }

    // MARK: 내부
    private static func quote(for code: String) -> Quote? {
        if let override = MockData.quoteOverrides[code] {
            return makeQuote(price: override.price, change: override.change, spark: override.spark)
        }
        if let stock = MockData.universe.first(where: { $0.code == code }), stock.price > 0 {
            return makeQuote(price: stock.price, change: stock.change, spark: [])
        }
        return nil
    }

    /// 전일 종가 = 현재가 / (1 + 등락률/100)로 역산(시세에 전일 종가를 부여).
    private static func makeQuote(price: Int, change: Double, spark: [Double]) -> Quote {
        let previousClose = change == 0 ? price : Int((Double(price) / (1 + change / 100)).rounded())
        return Quote(price: .krw(price), previousClose: .krw(max(1, previousClose)), changePercent: change, sparkline: spark)
    }
}
