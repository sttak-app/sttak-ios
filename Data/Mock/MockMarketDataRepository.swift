import Foundation

/// 시세·종목 Mock. 시세는 sttak-data 오버라이드 + Prototype 유니버스, 캔들은 결정적 생성.
struct MockMarketDataRepository: MarketDataRepository {

    func fetchQuotes(forStockCodes codes: [String]) async throws -> [String: Quote] {
        var result: [String: Quote] = [:]
        for code in codes {
            if let quote = Self.quote(for: code) { result[code] = quote }
        }
        return result
    }

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

    // MARK: 내부
    private static func quote(for code: String) -> Quote? {
        if let override = MockData.quoteOverrides[code] {
            return Quote(price: .krw(override.price), changePercent: override.change, sparkline: override.spark)
        }
        if let stock = MockData.universe.first(where: { $0.code == code }), stock.price > 0 {
            return Quote(price: .krw(stock.price), changePercent: stock.change, sparkline: [])
        }
        return nil
    }
}
