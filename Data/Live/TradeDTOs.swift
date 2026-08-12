import Foundation

// MARK: - 요청

/// POST /api/v1/trades 요청. 접수 모델(ADR-011)이라 체결가(price)는 보내지 않는다.
struct CreateTradeRequestDTO: Encodable, Sendable {
    let type: String       // "BUY" | "SELL"
    let stockCode: String
    let quantity: Int
    let rationale: String

    init(type: TradeType, stockCode: String, quantity: Int, rationale: String) {
        self.type = TradeDTOMapping.string(from: type)
        self.stockCode = stockCode
        self.quantity = quantity
        self.rationale = rationale
    }
}

// MARK: - 응답

/// POST /api/v1/trades 응답 — 접수된 PENDING 주문.
struct CreateTradeResponseDTO: Decodable, Sendable {
    let id: String
    let type: String
    let stockCode: String
    let quantity: Int
    let rationale: String
    let status: String
    let orderedAt: Date            // Instant(Z)
    let tradingDate: String?       // LocalDate(오프셋 없음) → String
    let fillBasis: String?
    let referencePrice: Int?

    func toDomain() -> Trade {
        Trade(
            id: id,
            type: TradeDTOMapping.type(from: type),
            stockCode: stockCode,
            quantity: quantity,
            rationale: TradeRationale(text: rationale),
            status: TradeDTOMapping.status(from: status),
            orderedAt: orderedAt,
            tradingDate: JSONCoding.parseKSTDate(tradingDate),
            fillBasis: TradeDTOMapping.fillBasis(from: fillBasis),
            referencePrice: referencePrice.map(Money.krw),
            filledPrice: nil,
            filledAt: nil,
            rejectedReason: nil,
            realizedProfit: nil,
            retrospective: nil
        )
    }
}

/// GET /api/v1/trades 배열 원소 — 모든 상태를 포함.
struct TradeDTO: Decodable, Sendable {
    let id: String
    let type: String
    let stockCode: String
    let stockName: String?         // 표시명은 뷰모델이 별도 조회 → 여기선 무시
    let quantity: Int
    let rationale: String
    let status: String
    let tradingDate: String?       // LocalDate(오프셋 없음)
    let fillBasis: String?
    let referencePrice: Int?
    let filledPrice: Int?
    let filledAt: Date?            // Instant(Z), FILLED만
    let rejectedReason: String?
    let realizedProfit: Int?
    let orderedAt: Date
    let retrospective: RetrospectiveDTO?

    func toDomain() -> Trade {
        Trade(
            id: id,
            type: TradeDTOMapping.type(from: type),
            stockCode: stockCode,
            quantity: quantity,
            rationale: TradeRationale(text: rationale),
            status: TradeDTOMapping.status(from: status),
            orderedAt: orderedAt,
            tradingDate: JSONCoding.parseKSTDate(tradingDate),
            fillBasis: TradeDTOMapping.fillBasis(from: fillBasis),
            referencePrice: referencePrice.map(Money.krw),
            filledPrice: filledPrice.map(Money.krw),
            filledAt: filledAt,
            rejectedReason: rejectedReason,
            realizedProfit: realizedProfit.map(Money.krw),
            retrospective: retrospective?.toDomain(id: "retro-\(id)", createdAt: filledAt ?? orderedAt)
        )
    }
}

/// GET /trades에 임베드되는 매도 회고(서버 생성, 정산 후).
struct RetrospectiveDTO: Decodable, Sendable {
    let summaryLine: String
    let goodPoints: [String]
    let watchPoints: [String]
    let isPartialSell: Bool

    // 서버는 id/생성시각/후속을 주지 않으므로 호출부(Trade)가 컨텍스트로 채운다.
    func toDomain(id: String, createdAt: Date) -> Retrospective {
        Retrospective(
            id: id,
            summaryLine: summaryLine,
            goodPoints: goodPoints,
            watchPoints: watchPoints,
            isPartialSell: isPartialSell,
            createdAt: createdAt,
            followUp: nil
        )
    }
}

/// GET /api/v1/portfolio 응답.
struct PortfolioDTO: Decodable, Sendable {
    let cash: Int
    let holdings: [HoldingDTO]

    func toDomain() -> Portfolio {
        Portfolio(cash: .krw(cash), holdings: holdings.map { $0.toDomain() })
    }
}

struct HoldingDTO: Decodable, Sendable {
    let stockCode: String
    let stockName: String?   // Holding에는 표시명이 없어 무시(뷰모델이 별도 조회)
    let quantity: Int
    let averagePrice: Int

    func toDomain() -> Holding {
        Holding(stockCode: stockCode, quantity: quantity, averagePrice: .krw(averagePrice))
    }
}

/// GET /api/v1/reason-templates 응답.
struct ReasonTemplatesDTO: Decodable, Sendable {
    let templates: [String]
}

// MARK: - 문자열 ↔ 도메인 매핑

enum TradeDTOMapping {
    static func string(from type: TradeType) -> String {
        type == .buy ? "BUY" : "SELL"
    }

    static func type(from raw: String) -> TradeType {
        raw.uppercased() == "SELL" ? .sell : .buy
    }

    static func status(from raw: String) -> TradeStatus {
        switch raw.uppercased() {
        case "FILLED": return .filled
        case "REJECTED": return .rejected
        case "CANCELLED", "CANCELED": return .cancelled
        default: return .pending
        }
    }

    static func fillBasis(from raw: String?) -> FillBasis? {
        switch raw?.uppercased() {
        case "OPEN": return .open
        case "CLOSE": return .close
        default: return nil
        }
    }
}
