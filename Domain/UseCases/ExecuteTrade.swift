import Foundation

/// ★ 모의 매수/매도 주문 접수. 규칙·검증만 담당하고 접수·정산은 PortfolioRepository에 위임.
/// - 근거 필수(빈 근거 거부) + 140자 상한(TradeRationale.maxLength 단일 상수) + 수량>0.
/// - 접수 모델(ADR-011)이라 체결가(price)는 클라이언트가 정하지 않는다(서버 배치가 결정).
struct ExecuteTrade: Sendable {
    let portfolio: PortfolioRepository

    func callAsFunction(
        type: TradeType,
        stockCode: String,
        quantity: Int,
        rationaleText: String
    ) async throws -> Trade {
        let trimmed = rationaleText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RepositoryError.validation(message: "매매 근거를 적어 주세요.")
        }
        guard trimmed.count <= TradeRationale.maxLength else {
            throw RepositoryError.validation(message: "근거는 \(TradeRationale.maxLength)자 이내로 적어 주세요.")
        }
        guard quantity > 0 else {
            throw RepositoryError.validation(message: "수량은 1주 이상이어야 해요.")
        }

        return try await portfolio.placeOrder(
            type: type,
            stockCode: stockCode,
            quantity: quantity,
            rationale: TradeRationale(text: trimmed)
        )
    }
}
