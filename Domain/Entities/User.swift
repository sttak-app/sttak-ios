import Foundation

/// 소셜 로그인 수단. (확정 B4)
enum AuthProvider: Sendable, Equatable {
    case kakao
    case google
    case apple
}

/// 사용자. 관심종목 최대 개수는 도메인 상수로 둔다(매직넘버 금지).
struct User: Sendable, Equatable, Identifiable {
    /// 관심종목 하드 캡(핸드오프: 최소 1 ~ 최대 5).
    static let maxWatchlistCount = 5

    let id: String
    let authProvider: AuthProvider
    let nickname: String
    let watchlistCodes: [String]
}
