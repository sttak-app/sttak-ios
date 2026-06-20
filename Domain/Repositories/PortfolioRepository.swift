import Foundation

/// 모의투자 포트폴리오(확정 C5: 서버가 원본, Mock=로컬 갱신).
/// 매핑: portfolio=GET /portfolio, execute=POST /trades, trades=GET /trades.
protocol PortfolioRepository: Sendable {
    /// 현재 포트폴리오(현금·보유).
    func fetchPortfolio() async throws -> Portfolio
    /// 매수/매도 실행 → cash·holdings 갱신 → 기록된 Trade 반환.
    /// (근거 필수·길이 검증 등 풀 도메인 규칙은 ExecuteTrade UseCase에서 강제)
    func execute(
        type: TradeType,
        stockCode: String,
        quantity: Int,
        price: Money,
        rationale: TradeRationale
    ) async throws -> Trade
    /// 매매 기록 전체(최신순).
    func fetchTrades() async throws -> [Trade]
}
