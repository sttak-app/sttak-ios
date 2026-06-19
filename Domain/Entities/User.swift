import Foundation

/// 소셜 로그인 수단. (확정 B4)
enum AuthProvider: Sendable, Equatable {
    case kakao
    case google
    case apple
}

/// 사용자. 관심종목 최대 5개 제한은 도메인 로직(UseCase)에서 강제한다.
struct User: Sendable, Equatable, Identifiable {
    let id: String
    let authProvider: AuthProvider
    let nickname: String
    let watchlistCodes: [String]  // 관심종목 코드 목록 (최대 5)
}
