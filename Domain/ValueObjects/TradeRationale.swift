import Foundation

/// 매매 근거. 사용자가 입력했거나 빠른선택에서 고른 텍스트(≤140자).
/// 빠른선택 프리셋 "카피"는 표현 계층의 정적 문구이며, 길이 검증은 도메인 로직 커밋에서 다룬다.
struct TradeRationale: Sendable, Equatable {
    /// 근거 최대 길이.
    static let maxLength = 140

    let text: String
}
