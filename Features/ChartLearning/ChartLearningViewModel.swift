import SwiftUI

/// 차트학습 상태. 종목·캔들·기간·줌/스크롤 뷰포트. (지표/신호·매매는 이후 커밋)
@MainActor
@Observable
final class ChartLearningViewModel {
    enum State: Equatable {
        case loading
        case loaded
        case error(String)
    }

    private(set) var state: State = .loading
    private(set) var stocks: [Stock] = []
    private(set) var selectedStockIndex = 0
    private(set) var candles: [Candle] = []
    private(set) var quote: Quote?
    private(set) var period: ChartPeriod = .month
    private(set) var viewport = ChartViewport(start: 0, count: ChartPeriod.month.candleCount)

    private let auth: AuthRepository
    private let marketData: MarketDataRepository

    init(auth: AuthRepository, marketData: MarketDataRepository) {
        self.auth = auth
        self.marketData = marketData
    }

    var selectedStock: Stock? {
        guard stocks.indices.contains(selectedStockIndex) else { return nil }
        return stocks[selectedStockIndex]
    }

    /// 윈도잉된 보이는 캔들 슬라이스.
    var visibleCandles: [Candle] {
        guard !candles.isEmpty else { return [] }
        let end = min(viewport.start + viewport.count, candles.count)
        let start = min(viewport.start, max(0, end - 1))
        return Array(candles[start..<end])
    }

    func load() async {
        state = .loading
        do {
            let user = try await auth.currentUser()
            let codes = user?.watchlistCodes ?? []
            stocks = try await marketData.fetchStocks(forCodes: codes)
            guard !stocks.isEmpty else {
                state = .error("관심종목을 먼저 추가해 주세요.")
                return
            }
            await loadCandles()
        } catch {
            state = .error("차트를 불러오지 못했어요.")
        }
    }

    func selectStock(_ index: Int) async {
        guard stocks.indices.contains(index), index != selectedStockIndex else { return }
        selectedStockIndex = index
        await loadCandles()
    }

    func selectPeriod(_ period: ChartPeriod) {
        self.period = period
        viewport = .forPeriod(period, total: candles.count)
    }

    /// 팬 — 시작 인덱스로 스크롤.
    func scroll(toStart start: Int) {
        viewport = viewport.scrolled(toStart: start, total: candles.count)
    }

    /// 줌 — 절대 count(중앙 고정).
    func zoom(toCount count: Int) {
        viewport = viewport.withCount(count, total: candles.count)
    }

    private func loadCandles() async {
        guard let stock = selectedStock else { return }
        state = .loading
        do {
            async let candlesTask = marketData.fetchCandles(forStockCode: stock.code)
            async let quotesTask = marketData.fetchQuotes(forStockCodes: [stock.code])
            let loaded = try await candlesTask
            quote = try await quotesTask[stock.code]
            candles = loaded
            viewport = .forPeriod(period, total: loaded.count)
            state = .loaded
        } catch RepositoryError.notFound {
            candles = []
            state = .error("이 종목은 아직 차트 데이터가 없어요.")
        } catch {
            candles = []
            state = .error("차트를 불러오지 못했어요.")
        }
    }
}
