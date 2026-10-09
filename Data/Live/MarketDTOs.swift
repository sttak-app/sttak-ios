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
    /// 계약상 date-time이지만 오프셋 유무가 확정되지 않아 String으로 받는다(앱은 사용하지 않음).
    /// Date로 받으면 형식이 다를 때 피드 전체가 디코딩 실패한다.
    let fetchedAt: String?
}

/// GET /api/v1/candles 응답의 캔들 한 개. 서버는 OHLCV를 정수(long, KRW)로 준다.
///
/// `date`는 OpenAPI에 `format: date-time`으로 선언돼 있지만, 이 백엔드는 같은 포맷으로 **오프셋 없는
/// LocalDateTime**을 주는 전례가 있다(퀴즈 nextAvailableAt·랭킹 updatedAt). 그래서 String으로 받아
/// `parseKSTDate`로 관대하게 파싱한다 — 오프셋이 있으면 그대로, 없으면 KST로 읽는다.
struct CandleDTO: Decodable, Sendable {
    let date: String
    let open: Int
    let high: Int
    let low: Int
    let close: Int
    let volume: Int

    // 지표 계산(Domain/Indicators)이 Double을 쓰므로 OHLC는 Double로 승격.
    // 날짜를 못 읽은 봉은 차트 x축·신호 매칭의 키가 없어 버린다(피드 전체 실패보다 안전).
    func toDomain() -> Candle? {
        guard let parsedDate = JSONCoding.parseKSTDate(date) else { return nil }
        return Candle(
            date: parsedDate,
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
