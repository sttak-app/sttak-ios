import Foundation

/// 보유 종목 한 줄. Portfolio의 구성 요소.
/// (프로토타입 sttak_port의 {hold, avg}를 다종목으로 일반화)
struct Holding: Sendable, Equatable {
    let stockCode: String
    let quantity: Int
    let averagePrice: Money  // 평균 매입 단가
}
