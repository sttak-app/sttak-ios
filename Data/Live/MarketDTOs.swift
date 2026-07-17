import Foundation

/// GET /api/v1/quotes 응답의 값(코드별 map). 금액은 정수 KRW.
struct QuoteDTO: Decodable, Sendable {
    let price: Int
    let previousClose: Int
    let changePercent: Double
    let sparkline: [Int]

    func toDomain() -> Quote {
        Quote(
            price: .krw(price),
            previousClose: .krw(previousClose),
            changePercent: changePercent,
            sparkline: sparkline.map(Double.init)
        )
    }
}

/// GET /api/v1/stocks · /stocks/search · /stocks/popular 응답 원소.
struct StockDTO: Decodable, Sendable {
    let code: String
    let name: String
    let sector: String
    let market: String      // "KOSPI" | "KOSDAQ"
    let currency: String    // "KRW" | "USD"

    func toDomain() -> Stock {
        Stock(
            code: code,
            name: name,
            sector: sector,
            market: Self.market(from: market),
            currency: Self.currency(from: currency)
        )
    }

    // 미지의 값은 국내 MVP 기본값으로 관대하게 처리(목록 전체 실패 방지).
    private static func market(from raw: String) -> Market {
        raw.uppercased() == "KOSDAQ" ? .kosdaq : .kospi
    }

    private static func currency(from raw: String) -> Currency {
        raw.uppercased() == "USD" ? .usd : .krw
    }
}
