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

/// GET /api/v1/candles 응답 본문 — 서버는 candles/fetchedAt 엔벨로프로 감싼다(뉴스 피드와 동일 계약).
struct CandleFeedDTO: Decodable, Sendable {
    let candles: [CandleDTO]
    let fetchedAt: Date?
}

/// GET /api/v1/candles 응답의 캔들 한 개. 서버는 OHLCV를 정수(long, KRW)로 준다.
struct CandleDTO: Decodable, Sendable {
    let date: Date          // UTC 자정 기준 일봉(T-1)
    let open: Int
    let high: Int
    let low: Int
    let close: Int
    let volume: Int

    // 지표 계산(Domain/Indicators)이 Double을 쓰므로 OHLC는 Double로 승격.
    func toDomain() -> Candle {
        Candle(
            date: date,
            open: Double(open),
            high: Double(high),
            low: Double(low),
            close: Double(close),
            volume: volume
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
