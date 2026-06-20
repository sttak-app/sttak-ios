import SwiftUI

/// 모의 매수/매도 시트 상태. 근거 필수 검증은 ExecuteTrade UseCase가, UI 비활성은 canExecute가 담당.
/// 매도 성공 시 RetrospectiveRepository 스트리밍으로 직후 회고를 점진 표시.
@MainActor
@Observable
final class TradeViewModel {
    enum Phase: Equatable {
        case input
        case submitting
        case completedBuy
        case retrospective
    }

    enum StreamingState: Equatable {
        case streaming, done, cancelled, error(String)
    }

    let type: TradeType
    let stockName: String
    let stockCode: String
    let price: Money

    var quantity = 10
    var rationaleText = ""
    private(set) var maxQuantity = 1
    private(set) var averageCost = Money.krw(0)
    private(set) var phase: Phase = .input
    private(set) var errorMessage: String?

    // 회고(매도)
    private(set) var retro: Retrospective?
    private(set) var realizedProfit = Money.krw(0)
    private(set) var retroState: StreamingState = .streaming
    private var retroTask: Task<Void, Never>?

    let presets: [String]
    private let onCompleted: () -> Void
    private let executeTrade: ExecuteTrade
    private let portfolio: PortfolioRepository
    private let retrospective: RetrospectiveRepository

    init(
        type: TradeType,
        stockCode: String,
        stockName: String,
        price: Money,
        executeTrade: ExecuteTrade,
        portfolio: PortfolioRepository,
        retrospective: RetrospectiveRepository,
        onCompleted: @escaping () -> Void
    ) {
        self.type = type
        self.stockCode = stockCode
        self.stockName = stockName
        self.price = price
        self.executeTrade = executeTrade
        self.portfolio = portfolio
        self.retrospective = retrospective
        self.onCompleted = onCompleted
        self.presets = type == .buy
            ? ["뉴스 호재가 실적으로 이어질 것 같아서", "차트가 골든크로스라 상승 전환 기대", "거래량이 늘어 관심이 가서"]
            : ["목표한 수익에 도달해서", "흐름이 꺾이는 것 같아서", "다른 종목에 투자하려고"]
    }

    var title: String { stockName + (type == .buy ? " 모의 매수" : " 모의 매도") }
    var maxRationaleLength: Int { TradeRationale.maxLength }
    var totalAmount: Money { .krw(price.amount * quantity) }
    var canExecute: Bool {
        !rationaleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && quantity > 0 && quantity <= maxQuantity
    }

    func load() async {
        guard let portfolio = try? await portfolio.fetchPortfolio() else { return }
        let holding = portfolio.holdings.first { $0.stockCode == stockCode }
        switch type {
        case .buy:
            maxQuantity = max(1, price.amount > 0 ? portfolio.cash.amount / price.amount : 1)
        case .sell:
            maxQuantity = max(0, holding?.quantity ?? 0)
        }
        averageCost = holding?.averagePrice ?? price
        quantity = min(max(1, quantity), max(1, maxQuantity))
    }

    func setQuantity(_ value: Int) {
        quantity = min(max(1, value), max(1, maxQuantity))
    }

    func pickPreset(_ text: String) { rationaleText = text }

    func execute() async {
        guard canExecute else { return }
        phase = .submitting
        errorMessage = nil
        let isPartial = type == .sell && quantity < maxQuantity
        do {
            let trade = try await executeTrade(
                type: type, stockCode: stockCode, quantity: quantity, price: price, rationaleText: rationaleText
            )
            onCompleted()
            if type == .sell {
                realizedProfit = .krw((price.amount - averageCost.amount) * quantity)
                startRetrospective(trade: trade, isPartialSell: isPartial)
                phase = .retrospective
            } else {
                phase = .completedBuy
            }
        } catch let error as RepositoryError {
            errorMessage = message(for: error)
            phase = .input
        } catch {
            errorMessage = "처리에 실패했어요. 다시 시도해 주세요."
            phase = .input
        }
    }

    func cancelRetrospective() { retroTask?.cancel() }

    func retryRetrospective() {
        guard case .error = retroState else { return }
        // 마지막 매도 정보로 재시작은 trade가 필요하므로, 단순히 닫도록 둔다(닫힘이 곧 취소).
    }

    // MARK: 내부
    private func startRetrospective(trade: Trade, isPartialSell: Bool) {
        retroState = .streaming
        let stream = retrospective.generateRetrospective(
            for: trade, realizedProfit: realizedProfit, isPartialSell: isPartialSell
        )
        retroTask = Task { [weak self] in
            do {
                for try await snapshot in stream {
                    if Task.isCancelled { break }
                    self?.retro = snapshot
                }
                self?.retroState = Task.isCancelled ? .cancelled : .done
            } catch {
                self?.retroState = Task.isCancelled ? .cancelled : .error("회고를 불러오지 못했어요.")
            }
        }
    }

    private func message(for error: RepositoryError) -> String {
        if case let .validation(message) = error { return message }
        return "처리에 실패했어요. 다시 시도해 주세요."
    }
}
