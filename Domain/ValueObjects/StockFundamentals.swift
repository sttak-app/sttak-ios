import Foundation

/// 종목 기초 정보(정보 지표). 핸드오프는 표시 문자열로 제공(시총 "424조", PER "14.2배" 등).
/// Live에서는 수치로 받아 포맷할 수 있으나 Mock 단계는 표시값 그대로.
struct StockFundamentals: Sendable, Equatable {
    let marketCap: String  // 시가총액
    let per: String        // 주가수익비율
    let pbr: String        // 주가순자산비율
}
