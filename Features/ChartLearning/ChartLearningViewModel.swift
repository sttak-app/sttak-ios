import SwiftUI

/// 차트학습 상태. 종목·캔들·기간·뷰포트 + 지표 오버레이·과거 신호·코치.
/// 지표/신호는 커밋 6 Domain/Indicators를 그대로 호출(재계산 없음).
@MainActor
@Observable
final class ChartLearningViewModel {
    enum State: Equatable {
        case loading, loaded, error(String)
    }

    /// 코치/마커용 신호 이벤트(번호 매겨진).
    struct SignalEvent: Identifiable {
        let id: Int            // 번호(1..)
        let candleIndex: Int
        let kind: ChartSignalKind
        let direction: PriceDirection
    }

    private(set) var state: State = .loading
    private(set) var stocks: [Stock] = []
    private(set) var selectedStockIndex = 0
    private(set) var candles: [Candle] = []
    private(set) var quote: Quote?
    private(set) var fundamentals: StockFundamentals?
    private(set) var period: ChartPeriod = .month
    private(set) var viewport = ChartViewport(start: 0, count: ChartPeriod.month.candleCount)

    private(set) var selectedIndicator: IndicatorKind?
    private(set) var explanationOpen = true
    private(set) var signalEvents: [SignalEvent] = []
    private(set) var selectedSignalIndex: Int?

    private(set) var portfolio: Portfolio?
    private(set) var valuation: PortfolioValuation?     // 자산 요약(EvaluatePortfolio 재사용 — 마이와 동일)
    private(set) var tradeIntent: TradeIntent?
    private var tradeCounter = 0

    private let auth: AuthRepository
    private let marketData: MarketDataRepository
    private let portfolioRepo: PortfolioRepository
    private let evaluate: EvaluatePortfolio

    // 도메인 전체 시리즈 캐시(뷰포트 변경 시 재계산 안 함)
    private var maFull: [Int: [Double?]] = [:]
    private var bandsFull: (middle: [Double?], upper: [Double?], lower: [Double?])?
    private var rsiFull: [Double?] = []

    private let maPeriods = [5, 20, 60, 120]
    private let maxSignals = 4
    private let signalMinGap = 5

    init(
        auth: AuthRepository,
        marketData: MarketDataRepository,
        portfolioRepo: PortfolioRepository,
        evaluate: EvaluatePortfolio
    ) {
        self.auth = auth
        self.marketData = marketData
        self.portfolioRepo = portfolioRepo
        self.evaluate = evaluate
    }

    /// 매수/매도 시트 진입 의도.
    struct TradeIntent: Identifiable, Equatable {
        let id: Int
        let type: TradeType
        let stockCode: String
        let stockName: String
        let price: Money
    }

    var selectedStock: Stock? {
        stocks.indices.contains(selectedStockIndex) ? stocks[selectedStockIndex] : nil
    }

    /// 현재 종목 보유 수량(트레이드 바).
    var heldQuantity: Int {
        guard let code = selectedStock?.code else { return 0 }
        return portfolio?.holdings.first { $0.stockCode == code }?.quantity ?? 0
    }

    /// 표시·거래에 쓰는 현재가. DEBUG 오프셋은 시세 레이어(MockMarketDataRepository)에 이미 반영됨.
    var displayPrice: Money? { quote?.price }
    var displayChangePercent: Double? { quote?.changePercent }

    func openBuy() {
        guard let stock = selectedStock, let price = displayPrice else { return }
        tradeCounter += 1
        tradeIntent = TradeIntent(id: tradeCounter, type: .buy, stockCode: stock.code, stockName: stock.name, price: price)
    }

    func openSell() {
        guard let stock = selectedStock, let price = displayPrice else { return }
        tradeCounter += 1
        tradeIntent = TradeIntent(id: tradeCounter, type: .sell, stockCode: stock.code, stockName: stock.name, price: price)
    }

    #if DEBUG
    /// 디버그 현재가 ±% 조정(시세 레이어에 반영 → 차트·자산요약·마이 일관). win/loss 회고·자산요약 확인용.
    func debugAdjustPrice(byPercent percent: Double) async {
        guard let code = selectedStock?.code else { return }
        await marketData.debugNudgePrice(byPercent: percent, forStockCode: code)
        await refreshAfterPriceChange()
    }

    func debugResetPrice() async {
        await marketData.debugResetPrices()
        await refreshAfterPriceChange()
    }

    private func refreshAfterPriceChange() async {
        if let code = selectedStock?.code {
            quote = try? await marketData.fetchQuotes(forStockCodes: [code])[code]
        }
        await refreshValuation()
    }
    #endif

    func dismissTrade() { tradeIntent = nil }

    func onTradeCompleted() async {
        portfolio = try? await portfolioRepo.fetchPortfolio()
        await refreshValuation()
    }

    /// 자산 요약 갱신 — EvaluatePortfolio 재사용(재계산 금지).
    func refreshValuation() async {
        valuation = try? await evaluate()
    }

    var visibleCandles: [Candle] {
        guard !candles.isEmpty else { return [] }
        let end = min(viewport.start + viewport.count, candles.count)
        let start = min(viewport.start, max(0, end - 1))
        return Array(candles[start..<end])
    }

    // MARK: 로드
    func load() async {
        state = .loading
        do {
            let user = try await auth.currentUser()
            stocks = try await marketData.fetchStocks(forCodes: user?.watchlistCodes ?? [])
            guard !stocks.isEmpty else { state = .error("관심종목을 먼저 추가해 주세요."); return }
            portfolio = try? await portfolioRepo.fetchPortfolio()
            await refreshValuation()
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
        selectedSignalIndex = nil
    }

    func scroll(toStart start: Int) {
        viewport = viewport.scrolled(toStart: start, total: candles.count)
    }

    func zoom(toCount count: Int) {
        viewport = viewport.withCount(count, total: candles.count)
    }

    // MARK: 지표
    func selectIndicator(_ kind: IndicatorKind) {
        if selectedIndicator == kind {
            selectedIndicator = nil
            signalEvents = []
            selectedSignalIndex = nil
            return
        }
        selectedIndicator = kind
        selectedSignalIndex = nil
        // 지표 누르면 3개월 프레이밍(핸드오프).
        period = .threeMonths
        viewport = .forPeriod(.threeMonths, total: candles.count)
        computeIndicatorSeries()
        computeSignals(for: kind)
    }

    func toggleExplanation() { explanationOpen.toggle() }

    /// 코치 예시/마커 → 그 시점으로 차트 이동 + 선택.
    func focusSignal(candleIndex: Int) {
        let count = min(80, max(44, viewport.count))
        let start = candleIndex - count / 2
        viewport = .clamped(start: start, count: count, total: candles.count)
        selectedSignalIndex = candleIndex
    }

    // MARK: 예시 navigator (신호 이벤트 재사용)
    /// 현재 보고 있는 예시 번호(1..). 미선택이면 nil.
    var currentExampleNumber: Int? {
        selectedSignalIndex.flatMap { idx in signalEvents.first { $0.candleIndex == idx }?.id }
    }
    var exampleCount: Int { signalEvents.count }

    /// 다음 예시로 순환 이동.
    func nextExample() {
        guard !signalEvents.isEmpty else { return }
        let current = currentExampleNumber ?? 0
        let nextID = (current % signalEvents.count) + 1
        if let next = signalEvents.first(where: { $0.id == nextID }) { focusSignal(candleIndex: next.candleIndex) }
    }

    /// 예시 선택 해제 → 용어(설명·예시 목록)로 돌아가기. 오버레이는 유지.
    func backToTerm() { selectedSignalIndex = nil }

    /// 차트 탭(날짜) → 그 봉에 신호가 있으면 선택.
    func selectCandle(at date: Date) {
        guard let index = candles.firstIndex(where: { $0.date == date }) else { return }
        if signalEvents.contains(where: { $0.candleIndex == index }) {
            selectedSignalIndex = index
        }
    }

    // MARK: 코치 파생값
    var currentReading: String? {
        guard let kind = selectedIndicator, let last = candles.indices.last else { return nil }
        let price = candles[last].close
        switch kind {
        case .movingAverage:
            guard let ma5 = maFull[5]?[last], let ma20 = maFull[20]?[last] else { return nil }
            let above = price > ma20
            let shortAbove = ma5 > ma20
            let trend = (above && shortAbove) ? "위쪽" : (!above && !shortAbove ? "아래쪽" : "중립")
            return "지금은 가격이 20일선 \(above ? "위" : "아래")에 있고 단기선이 장기선 \(shortAbove ? "위" : "아래")라, 흐름은 ‘\(trend)’으로 읽혀요."
        case .rsi:
            guard let rsi = rsiFull[safe: last] ?? nil else { return nil }
            let zone = rsi >= 70 ? "과열 구간" : (rsi <= 30 ? "과매도 구간" : "중립 구간")
            return "지금 RSI는 약 \(Int(rsi.rounded()))로 \(zone)이에요."
        case .bollingerBands:
            guard let middle = bandsFull?.middle[last] else { return nil }
            return "지금 가격은 중간선 \(price > middle ? "위" : "아래")에 있어요. 위·아래 띠 사이에서 움직이는 폭을 함께 보세요."
        case .info, .supportResistance, .volume:
            return nil
        }
    }

    /// 선택된 신호의 상세(코치 디테일 카드).
    struct SignalDetail {
        let number: Int
        let kindLabel: String
        let daysAgo: Int
        let description: String
        let beforePrice: Int
        let afterPrice: Int
        let percentText: String
        let direction: PriceDirection
        let afterText: String
    }

    var selectedSignalDetail: SignalDetail? {
        guard let index = selectedSignalIndex,
              let event = signalEvents.first(where: { $0.candleIndex == index }),
              candles.indices.contains(index) else { return nil }
        let before = candles[index].close
        let target = min(candles.count - 1, index + ChartSignalDetector.forwardWindow)
        let after = candles[target].close
        let pct = before != 0 ? (after - before) / before * 100 : 0
        return SignalDetail(
            number: event.id,
            kindLabel: IndicatorCopy.signalLabel(event.kind),
            daysAgo: candles.count - 1 - index,
            description: IndicatorCopy.signalDescription(event.kind),
            beforePrice: Int(before.rounded()),
            afterPrice: Int(after.rounded()),
            percentText: Formatters.signedPercent(pct, fractionDigits: 1),
            direction: event.direction,
            afterText: IndicatorCopy.afterText(event.direction)
        )
    }

    // MARK: 렌더러용 오버레이 (도메인 시리즈 → 보이는 슬라이스)
    var chartOverlay: ChartOverlay {
        guard let kind = selectedIndicator, !candles.isEmpty else { return .none }
        let visStart = viewport.start
        let visEnd = min(viewport.start + viewport.count, candles.count)
        guard visStart < visEnd else { return .none }
        let range = visStart..<visEnd

        var overlay = ChartOverlay()
        switch kind {
        case .movingAverage:
            overlay.movingAverages = maPeriods.compactMap { period in
                guard let series = maFull[period] else { return nil }
                let points = range.compactMap { i -> DatedValue? in
                    guard let v = series[i] else { return nil }
                    return DatedValue(date: candles[i].date, value: v)
                }
                return MovingAverageLine(period: period, color: maColor(period), points: points)
            }
        case .bollingerBands:
            if let bands = bandsFull {
                overlay.bollinger = range.compactMap { i in
                    guard let u = bands.upper[i], let m = bands.middle[i], let l = bands.lower[i] else { return nil }
                    return BollingerPoint(date: candles[i].date, upper: u, middle: m, lower: l)
                }
            }
        case .rsi:
            overlay.rsi = range.compactMap { i in
                guard let v = rsiFull[safe: i] ?? nil else { return nil }
                return DatedValue(date: candles[i].date, value: v)
            }
        case .volume:
            overlay.showVolume = true
        case .supportResistance:
            let visible = candles[range]
            if let lo = visible.map(\.low).min(), let hi = visible.map(\.high).max() {
                overlay.supportResistance = SupportResistanceLevels(support: lo, resistance: hi)
            }
        case .info:
            break
        }

        overlay.signals = signalEvents.compactMap { event in
            guard range.contains(event.candleIndex) else { return nil }
            let end = min(candles.count - 1, event.candleIndex + ChartSignalDetector.forwardWindow)
            return SignalMarker(
                id: event.id,
                date: candles[event.candleIndex].date,
                regionEnd: candles[end].date,
                high: candles[event.candleIndex].high,
                direction: event.direction
            )
        }
        overlay.selectedDate = selectedSignalIndex.flatMap { candles.indices.contains($0) ? candles[$0].date : nil }
        return overlay
    }

    // MARK: 내부
    private func loadCandles() async {
        guard let stock = selectedStock else { return }
        state = .loading
        selectedSignalIndex = nil
        do {
            async let candlesTask = marketData.fetchCandles(forStockCode: stock.code)
            async let quotesTask = marketData.fetchQuotes(forStockCodes: [stock.code])
            async let fundTask = marketData.fetchFundamentals(forCode: stock.code)
            let loaded = try await candlesTask
            quote = try await quotesTask[stock.code]
            fundamentals = try await fundTask
            candles = loaded
            viewport = .forPeriod(period, total: loaded.count)
            if let kind = selectedIndicator {
                computeIndicatorSeries()
                computeSignals(for: kind)
            }
            state = .loaded
        } catch RepositoryError.notFound {
            candles = []; state = .error("이 종목은 아직 차트 데이터가 없어요.")
        } catch {
            candles = []; state = .error("차트를 불러오지 못했어요.")
        }
    }

    /// 커밋 6 도메인으로 전체 시리즈 계산(1회).
    private func computeIndicatorSeries() {
        guard !candles.isEmpty else { return }
        maFull = Dictionary(uniqueKeysWithValues: maPeriods.map { ($0, Indicators.simpleMovingAverage(candles, period: $0)) })
        let bands = Indicators.bollingerBands(candles)
        bandsFull = (bands.middle, bands.upper, bands.lower)
        rsiFull = Indicators.relativeStrengthIndex(candles)
    }

    /// 커밋 6 신호 탐지 → 지표 종류로 필터 → 병합·최근 cap → 번호.
    private func computeSignals(for kind: IndicatorKind) {
        let kinds = Set(IndicatorCopy.signalKinds(kind))
        guard !kinds.isEmpty else { signalEvents = []; return }
        let detected = ChartSignalDetector.detect(candles).filter { kinds.contains($0.kind) }

        // 5봉 이내 인접 신호 병합(이후 것 유지) → 최근 maxSignals개.
        var deduped: [ChartSignal] = []
        for signal in detected {
            if let last = deduped.last, signal.candleIndex - last.candleIndex < signalMinGap {
                deduped[deduped.count - 1] = signal
            } else {
                deduped.append(signal)
            }
        }
        let recent = Array(deduped.suffix(maxSignals))
        signalEvents = recent.enumerated().map { offset, signal in
            SignalEvent(id: offset + 1, candleIndex: signal.candleIndex, kind: signal.kind, direction: signal.subsequentDirection)
        }
    }

    private func maColor(_ period: Int) -> Color {
        switch period {
        case 5: return AppColor.accent
        case 20: return AppColor.indicatorMA
        case 60: return AppColor.indicatorRSI
        default: return AppColor.textMuted2
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
