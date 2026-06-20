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

    init(cash: Int = MockData.initialCash) {
        self.cash = cash
        self.holdings = []
        self.trades = []
        self.user = nil
        self.quizLastTakenAt = nil
    }

    // MARK: 인증
    func setUser(_ newUser: User?) { user = newUser }

    // MARK: 포트폴리오
    func portfolioSnapshot() -> Portfolio { Portfolio(cash: .krw(cash), holdings: holdings) }
    func allTrades() -> [Trade] { trades.reversed() } // 최신순

    /// 매수/매도 기록 + cash·holdings 갱신. (근거 필수 등 풀 검증은 ExecuteTrade UseCase)
    func recordTrade(
        type: TradeType,
        stockCode: String,
        quantity: Int,
        price: Money,
        rationale: TradeRationale
    ) throws -> Trade {
        guard quantity > 0 else { throw RepositoryError.validation(message: "수량은 1 이상이어야 해요.") }
        let amount = price.amount * quantity

        switch type {
        case .buy:
            guard cash >= amount else { throw RepositoryError.validation(message: "보유 현금이 부족해요.") }
            cash -= amount
            applyBuy(stockCode: stockCode, quantity: quantity, price: price)
        case .sell:
            let held = holdings.first { $0.stockCode == stockCode }?.quantity ?? 0
            guard held >= quantity else { throw RepositoryError.validation(message: "보유 수량이 부족해요.") }
            cash += amount
            applySell(stockCode: stockCode, quantity: quantity)
        }

        let trade = Trade(
            id: "trade-\(trades.count)",
            type: type,
            stockCode: stockCode,
            quantity: quantity,
            price: price,
            rationale: rationale,
            executedAt: Date(),
            retrospective: nil
        )
        trades.append(trade)
        return trade
    }

    // MARK: 퀴즈/자본금
    func addCapital(_ amount: Int) { cash += amount }

    /// 퀴즈 결과 기록(쿨다운 + 지난 세트 보관). 자본금 적립은 별도(creditCash).
    func recordQuizResult(correctCount: Int, earnedCapital: Money, takenAt: Date) {
        quizLastTakenAt = takenAt
        lastQuizCompletion = QuizCompletion(takenAt: takenAt, correctCount: correctCount, earnedCapital: earnedCapital)
    }

    #if DEBUG
    func clearQuizCooldown() {
        quizLastTakenAt = nil
        lastQuizCompletion = nil
    }
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
