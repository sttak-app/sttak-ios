import Foundation

/// Mock 단계의 공유 인메모리 상태(프로토타입 localStorage 공유키에 대응).
/// 포트폴리오·퀴즈·인증 Mock이 이 actor를 공유해 "동작하는 앱"을 만든다(확정 C5: Mock=로컬).
/// 생성은 부작용 없음(인메모리). AppContainer 와이어링은 커밋 9.
actor MockLocalStore {
    private(set) var user: User?
    private(set) var cash: Int                 // KRW (단일 통화 = 모의투자 자본금)
    private(set) var holdings: [Holding]
    private(set) var trades: [Trade]
    private(set) var quizLastTakenAt: Date?
    private(set) var lastQuizCompletion: QuizCompletion?

    init(cash: Int = MockData.initialCash, holdings: [Holding] = [], trades: [Trade] = []) {
        self.cash = cash
        self.holdings = holdings
        self.trades = trades
        self.user = nil
        self.quizLastTakenAt = nil
    }

    // MARK: 인증
    func setUser(_ newUser: User?) { user = newUser }

    /// 회원탈퇴 — 로컬 상태 전부 초기화(영구 삭제 시뮬레이션).
    func eraseAccountData() {
        user = nil
        cash = MockData.initialCash
        holdings = []
        trades = []
        quizLastTakenAt = nil
        lastQuizCompletion = nil
        quizCycleAnswered = 0
        quizCycleCorrect = 0
        quizCycleEarned = 0
        #if DEBUG
        debugPriceOffsets = [:]
        #endif
    }

    // MARK: 포트폴리오
    func portfolioSnapshot() -> Portfolio { Portfolio(cash: .krw(cash), holdings: holdings) }
    func allTrades() -> [Trade] { trades.reversed() } // 최신순

    /// 매수/매도 접수 + 즉시 정산(Mock) → cash·holdings 갱신. (근거 필수 등 풀 검증은 ExecuteTrade UseCase)
    /// 체결가는 클라이언트가 넘기지 않으므로 시세 레이어에서 내부 조회한다(Live와 동일 계약).
    func recordTrade(
        type: TradeType,
        stockCode: String,
        quantity: Int,
        rationale: TradeRationale
    ) throws -> Trade {
        guard quantity > 0 else { throw RepositoryError.validation(message: "수량은 1 이상이어야 해요.") }
        let price = Money.krw(currentPrice(for: stockCode))
        let amount = price.amount * quantity

        var realizedProfit: Money?
        switch type {
        case .buy:
            guard cash >= amount else { throw RepositoryError.validation(message: "보유 현금이 부족해요.") }
            cash -= amount
            applyBuy(stockCode: stockCode, quantity: quantity, price: price)
        case .sell:
            let position = holdings.first { $0.stockCode == stockCode }
            let held = position?.quantity ?? 0
            guard held >= quantity else { throw RepositoryError.validation(message: "보유 수량이 부족해요.") }
            // 평단은 매도 전 값으로 실현손익 계산.
            let avg = position?.averagePrice.amount ?? price.amount
            realizedProfit = .krw((price.amount - avg) * quantity)
            cash += amount
            applySell(stockCode: stockCode, quantity: quantity)
        }

        let now = Date()
        let trade = Trade(
            id: "trade-\(trades.count)",
            type: type,
            stockCode: stockCode,
            quantity: quantity,
            rationale: rationale,
            status: .filled,                                   // Mock은 즉시 체결
            orderedAt: now,
            tradingDate: Self.todayKST(),
            fillBasis: type == .buy ? .open : .close,
            referencePrice: price,
            filledPrice: price,
            filledAt: now,
            rejectedReason: nil,
            realizedProfit: realizedProfit,
            retrospective: nil
        )
        trades.append(trade)
        return trade
    }

    /// 체결가 내부 조회 — 시세 오버라이드/유니버스 base + DEBUG 오프셋(MockMarketDataRepository와 동일).
    /// (테스트는 debugSetPrice로 절대가를 주입해 정산 수식을 검증한다.)
    private func currentPrice(for code: String) -> Int {
        #if DEBUG
        if let forced = debugForcedPrices[code] { return max(1, forced) }
        #endif
        let base = MockData.quoteOverrides[code]?.price
            ?? MockData.universe.first { $0.code == code }?.price
            ?? 0
        #if DEBUG
        return max(1, base + debugPriceOffset(for: code))
        #else
        return max(1, base)
        #endif
    }

    /// 정산 기준일(익영업일 근사) — Mock은 KST 오늘 자정으로 둔다.
    private static func todayKST() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar.startOfDay(for: Date())
    }

    // MARK: 퀴즈/자본금
    func addCapital(_ amount: Int) { cash += amount }

    /// 진행 중 퀴즈 사이클(문항별 채점) 상태 — 서버의 answeredInCycle을 로컬로 재현.
    private(set) var quizCycleAnswered = 0
    private(set) var quizCycleCorrect = 0
    private(set) var quizCycleEarned = 0

    /// 문항 하나 채점 반영. 정답이면 자본금도 적립(서버가 submit 시점에 적립하는 동작을 미러링).
    func recordQuizAnswer(isCorrect: Bool, reward: Int) {
        quizCycleAnswered += 1
        if isCorrect {
            quizCycleCorrect += 1
            quizCycleEarned += reward
            cash += reward
        }
    }

    /// 사이클(3문제) 완료 — 쿨다운 시작 + 지난 세트 요약 보관, 진행 상태 리셋.
    func completeQuizCycle(takenAt: Date) {
        quizLastTakenAt = takenAt
        lastQuizCompletion = QuizCompletion(
            takenAt: takenAt,
            correctCount: quizCycleCorrect,
            earnedCapital: .krw(quizCycleEarned)
        )
        quizCycleAnswered = 0
        quizCycleCorrect = 0
        quizCycleEarned = 0
    }

    #if DEBUG
    func clearQuizCooldown() {
        quizLastTakenAt = nil
        lastQuizCompletion = nil
        quizCycleAnswered = 0
        quizCycleCorrect = 0
        quizCycleEarned = 0
    }

    // 디버그 시세 오프셋(원, 종목별) — 차트에서 조정 → 시세 레이어 공유 → 차트·자산요약·마이 일관 반영.
    private(set) var debugPriceOffsets: [String: Int] = [:]
    func debugAddPriceOffset(_ delta: Int, for code: String) { debugPriceOffsets[code, default: 0] += delta }
    func debugPriceOffset(for code: String) -> Int { debugPriceOffsets[code] ?? 0 }
    func clearDebugPriceOffsets() { debugPriceOffsets = [:] }

    // 테스트 전용 절대 체결가 주입 — 정산 수식(가중평단·실현손익) 검증용. base·offset보다 우선.
    private var debugForcedPrices: [String: Int] = [:]
    func debugSetPrice(_ amount: Int, for code: String) { debugForcedPrices[code] = amount }
    #endif

    // MARK: 내부
    private func applyBuy(stockCode: String, quantity: Int, price: Money) {
        if let index = holdings.firstIndex(where: { $0.stockCode == stockCode }) {
            let existing = holdings[index]
            let totalQty = existing.quantity + quantity
            let totalCost = existing.averagePrice.amount * existing.quantity + price.amount * quantity
            let avg = totalQty > 0 ? totalCost / totalQty : 0
            holdings[index] = Holding(stockCode: stockCode, quantity: totalQty, averagePrice: .krw(avg))
        } else {
            holdings.append(Holding(stockCode: stockCode, quantity: quantity, averagePrice: price))
        }
    }

    private func applySell(stockCode: String, quantity: Int) {
        guard let index = holdings.firstIndex(where: { $0.stockCode == stockCode }) else { return }
        let remaining = holdings[index].quantity - quantity
        if remaining > 0 {
            holdings[index] = Holding(
                stockCode: stockCode,
                quantity: remaining,
                averagePrice: holdings[index].averagePrice // 평단 유지
            )
        } else {
            holdings.remove(at: index)
        }
    }
}
