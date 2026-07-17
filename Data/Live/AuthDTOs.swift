import Foundation

/// GET /api/v1/me · 로그인 응답의 user.
struct UserDTO: Decodable, Sendable {
    let id: String
    let nickname: String
    let authProvider: String        // "KAKAO" | "GOOGLE" | "APPLE"
    let watchlistCodes: [String]

    func toDomain() -> User {
        User(
            id: id,
            authProvider: Self.provider(from: authProvider),
            nickname: nickname,
            watchlistCodes: watchlistCodes
        )
    }

    private static func provider(from raw: String) -> AuthProvider {
        switch raw.uppercased() {
        case "KAKAO": return .kakao
        case "GOOGLE": return .google
        case "APPLE": return .apple
        default: return .dev // dev 폴백 사용자 등 미지의 값은 dev로 취급
        }
    }
}

/// POST /api/v1/auth/kakao 응답.
struct KakaoLoginResponseDTO: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
    let isNewUser: Bool
    let user: UserDTO
}

/// PATCH /api/v1/me/watchlist 요청 바디.
struct WatchlistUpdateRequestDTO: Encodable, Sendable {
    let codes: [String]
}
