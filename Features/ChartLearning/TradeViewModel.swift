import SwiftUI

/// 모의 매수/매도 시트 상태. 근거 필수 검증은 ExecuteTrade UseCase가, UI 비활성은 canExecute가 담당.
/// 접수 모델(ADR-011): 실행 → 주문 접수(PENDING) → "다음 영업일 체결 예정" 안내. 즉시 체결·회고 스트리밍 없음.
@MainActor
@Observable
final class TradeViewModel {
    enum Phase: Equatable {
        case input        // 입력 중
        case submitting   // 접수 요청 중
        case submitted    // 접수 완료(정산 대기 안내)
    }

    let type: TradeType
    let stockName: String
    let stockCode: String
    let price: Money            // 표시·매수가능수량 추정용(서버로 전송하지 않음 — 체결가는 서버가 결정)

    var quantity = 10
    var rationaleText = ""
    private(set) var maxQuantity = 1
    private(set) var averageCost = Money.krw(0)
    private(set) var buyingPower = Money.krw(0)   // 매수 가능 금액 = 보유 현금
    private(set) var phase: Phase = .input
    private(set) var errorMessage: String?
    private(set) var submittedTrade: Trade?        // 접수 결과(체결 예정일·기준·참고가 표시)

    /// 매매 근거 프리셋(서버 GET /reason-templates). 로드 실패 시 아래 기본값 유지.
    private(set) var presets: [String]
    private let onCompleted: () -> Void
    private let executeTrade: ExecuteTrade
    private let portfolio: PortfolioRepository

    init(
        type: TradeType,
        stockCode: String,
        stockName: String,
        price: Money,
        executeTrade: ExecuteTrade,
        portfolio: PortfolioRepository,
        onCompleted: @escaping () -> Void
    ) {
        self.type = type
        self.stockCode = stockCode
        self.stockName = stockName
        self.price = price
        self.executeTrade = executeTrade
        self.portfolio = portfolio
        self.onCompleted = onCompleted
        // 서버 프리셋 도착 전 기본 폴백(load에서 교체).
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
        // 서버 근거 프리셋(실패 시 기본값 유지).
        if let templates = try? await portfolio.fetchReasonTemplates(type: type), !templates.isEmpty {
            presets = templates
        }
        guard let portfolio = try? await portfolio.fetchPortfolio() else { return }
        buyingPower = portfolio.cash
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
        do {
            let trade = try await executeTrade(
                type: type, stockCode: stockCode, quantity: quantity, rationaleText: rationaleText
            )
            submittedTrade = trade
            onCompleted()          // 차트/자산요약 갱신(체결 시 보유 반영, 접수만이면 변화 없음)
            phase = .submitted
        } catch let error as RepositoryError {
            errorMessage = message(for: error)
            phase = .input
        } catch {
            errorMessage = "처리에 실패했어요. 다시 시도해 주세요."
            phase = .input
        }
    }

    private func message(for error: RepositoryError) -> String {
        if case let .validation(message) = error { return message }
        return "처리에 실패했어요. 다시 시도해 주세요."
    }
}
