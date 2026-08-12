import Foundation

/// 포트폴리오/매매 Live. 접수→익일 배치 정산 모델(ADR-011).
/// 매핑: GET /portfolio, POST /trades(price 없음), GET /trades, DELETE /trades/{id}, GET /reason-templates.
struct LivePortfolioRepository: PortfolioRepository {
    let api: APIClient

    func fetchPortfolio() async throws -> Portfolio {
        let dto: PortfolioDTO = try await api.request(.get("/api/v1/portfolio"))
        return dto.toDomain()
    }

    func placeOrder(
        type: TradeType,
        stockCode: String,
        quantity: Int,
        rationale: TradeRationale
    ) async throws -> Trade {
        let body: Data
        do {
            body = try JSONCoding.encoder().encode(
                CreateTradeRequestDTO(type: type, stockCode: stockCode, quantity: quantity, rationale: rationale.text)
            )
        } catch {
            throw RepositoryError.unknown
        }
        let dto: CreateTradeResponseDTO = try await api.request(.post("/api/v1/trades", body: body))
        return dto.toDomain()
    }

    func fetchTrades() async throws -> [Trade] {
        let dtos: [TradeDTO] = try await api.request(.get("/api/v1/trades"))  // 서버가 orderedAt desc(최신순)
        return dtos.map { $0.toDomain() }
    }

    func cancelOrder(id: String) async throws {
        try await api.requestVoid(.delete("/api/v1/trades/\(id)"))
    }

    func fetchReasonTemplates(type: TradeType) async throws -> [String] {
        let dto: ReasonTemplatesDTO = try await api.request(
            .get("/api/v1/reason-templates", query: [
                URLQueryItem(name: "type", value: TradeDTOMapping.string(from: type))
            ])
        )
        return dto.templates
    }

    // 서버가 보상 적립의 SSOT(퀴즈 정답 등). 클라이언트 적립 엔드포인트는 없어 no-op —
    // 다음 fetchPortfolio가 서버 잔고를 그대로 반영한다.
    func creditCash(_ amount: Money) async throws {}
}
