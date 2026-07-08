import Foundation

/// 거래 시장. 해외 확장(확정 D7) 대비해 일반화. MVP는 국내만.
enum Market: Sendable, Equatable, CaseIterable {
    case kospi
    case kosdaq
    // 추후: nyse, nasdaq ...
}

/// 종목. `code`가 식별자. 현재가/등락률은 변동값이라 Quote로 분리한다.
struct Stock: Sendable, Equatable, Hashable, Identifiable {
    let code: String
    let name: String
    let sector: String
    let market: Market
    let currency: Currency

    var id: String { code }
}
