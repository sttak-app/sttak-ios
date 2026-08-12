import Foundation

/// 모의투자 포트폴리오(서버가 원본, Mock=로컬 갱신). 매매는 접수→익일 배치 정산(ADR-011).
/// 매핑: portfolio=GET /portfolio, placeOrder=POST /trades, trades=GET /trades,
///       cancelOrder=DELETE /trades/{id}, reasonTemplates=GET /reason-templates.
protocol PortfolioRepository: Sendable {
    /// 현재 포트폴리오(현금·보유).
    func fetchPortfolio() async throws -> Portfolio
    /// 매수/매도 주문 접수(서버가 체결가를 정하므로 price는 보내지 않는다) → 접수된 PENDING Trade 반환.
    /// (근거 필수·길이 검증 등 풀 도메인 규칙은 ExecuteTrade UseCase에서 강제)
    func placeOrder(
        type: TradeType,
        stockCode: String,
        quantity: Int,
        rationale: TradeRationale
    ) async throws -> Trade
    /// 매매 기록 전체(최신순, 모든 상태 포함).
    func fetchTrades() async throws -> [Trade]
    /// PENDING 주문 취소. 매핑: DELETE /trades/{id}.
    func cancelOrder(id: String) async throws
    /// 매매 근거 프리셋(매수/매도별). 매핑: GET /reason-templates?type=.
    func fetchReasonTemplates(type: TradeType) async throws -> [String]
    /// 비거래 현금 적립(퀴즈 보상 등). 서버가 보상 트랜잭션으로 처리(Live는 no-op, Mock은 로컬 반영).
    func creditCash(_ amount: Money) async throws
}
