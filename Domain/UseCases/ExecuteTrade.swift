import Foundation

/// ★ 모의 매수/매도 실행. 규칙·검증만 담당하고 cash/holdings 계산은 PortfolioRepository(커밋 8)에 위임.
/// - 근거 필수(빈 근거 거부) + 140자 상한(TradeRationale.maxLength 단일 상수) + 수량>0.
/// - 매도 시 회고 트리거는 호출부(ViewModel)가 반환된 매도 Trade로 수행한다.
struct ExecuteTrade: Sendable {
    let portfolio: PortfolioRepository

    func callAsFunction(
        type: TradeType,
        stockCode: String,
        quantity: Int,
        price: Money,
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

        return try await portfolio.execute(
            type: type,
            stockCode: stockCode,
            quantity: quantity,
            price: price,
            rationale: TradeRationale(text: trimmed)
        )
    }
}
