import Foundation

/// 뉴스/공시의 감정 판단. 의미만 보유하며 색 매핑(빨강/회색/파랑)은 표현 계층의 몫이다.
enum Sentiment: Sendable, Equatable, CaseIterable {
    case positive  // 호재
    case neutral   // 중립
    case negative  // 악재
}
