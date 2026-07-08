import Foundation

/// 통화 단위. MVP는 KRW만 노출하되 해외 확장(확정 D7) 대비해 타입을 일반화한다.
enum Currency: Sendable, Equatable, CaseIterable {
    case krw
    case usd
}

/// 금액 값 객체. `amount`는 통화의 최소 단위 정수(KRW=원, USD=센트).
/// 통화별 포맷팅은 표현 계층에서 처리한다(도메인은 값만 보유).
struct Money: Sendable, Equatable {
    let amount: Int
    let currency: Currency

    init(amount: Int, currency: Currency = .krw) {
        self.amount = amount
        self.currency = currency
    }

    /// 원화 금액 편의 생성자.
    static func krw(_ amount: Int) -> Money {
        Money(amount: amount, currency: .krw)
    }
}
