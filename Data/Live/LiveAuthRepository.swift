import Foundation

/// 인증 Live: 카카오 SDK 토큰 → 백엔드 교환(자체 JWT 발급, Keychain 보관).
/// dev 폴백(.dev): 카카오 키 준비 전 고정 UUID를 X-User-Id 헤더로 보내는 개발자 로그인.
struct LiveAuthRepository: AuthRepository {
    let api: APIClient
    let tokenStore: any TokenStoring
    let socialLogin: any SocialLoginService

    func signIn(with provider: AuthProvider) async throws -> User {
        switch provider {
        case .kakao:
            return try await signInWithKakao()
        case .dev:
            return await signInAsDev()
        case .google, .apple:
            throw RepositoryError.validation(message: "아직 준비 중인 로그인이에요.")
        }
    }

    func currentUser() async throws -> User? {
        // 자격이 전혀 없으면 서버 호출 없이 미인증.
        let hasAccess = await tokenStore.accessToken() != nil
        let hasDev = await tokenStore.devUserId() != nil
        guard hasAccess || hasDev else { return nil }
        do {
            let dto: UserDTO = try await api.request(.get("/api/v1/me"))
            return dto.toDomain()
        } catch RepositoryError.unauthorized {
            // 리프레시까지 실패한 상태 — 세션 만료로 취급.
            return nil
        } catch RepositoryError.notFound where hasDev {
            // dev 사용자가 서버에 아직 없을 수 있음 — 로컬 플레이스홀더로 계속 진행.
            return devPlaceholderUser()
        }
    }

    func updateWatchlist(_ codes: [String]) async throws -> User {
        let body = try encode(WatchlistUpdateRequestDTO(codes: codes))
        let dto: UserDTO = try await api.request(.patch("/api/v1/me/watchlist", body: body))
        return dto.toDomain()
    }

    func signOut() async throws {
        // 서버 로그아웃은 실패해도 로컬 세션은 반드시 비운다(가역 로그아웃).
        try? await api.requestVoid(.post("/api/v1/auth/logout"))
        await tokenStore.clearTokens()
        await tokenStore.setDevUserId(nil)
    }

    func deleteAccount() async throws {
        // 탈퇴 계약(DELETE /me)은 백엔드 미확정 — 엔드포인트 부재(404)는 로컬 정리로 진행.
        do {
            try await api.requestVoid(.delete("/api/v1/me"))
        } catch RepositoryError.notFound {
            // 서버 미구현 — 로컬 세션만 정리.
        }
        await tokenStore.clearTokens()
        await tokenStore.setDevUserId(nil)
    }

    // MARK: 내부

    private func signInWithKakao() async throws -> User {
        let kakaoToken = try await socialLogin.kakaoAccessToken()
        let body = try encode(["accessToken": kakaoToken])
        let response: KakaoLoginResponseDTO = try await api.request(
            .post("/api/v1/auth/kakao", body: body, requiresAuth: false)
        )
        await tokenStore.save(accessToken: response.accessToken, refreshToken: response.refreshToken)
        await tokenStore.setDevUserId(nil) // JWT를 얻었으니 dev 폴백 해제
        // isNewUser는 서버가 주지만 온보딩 플로우가 로그인 → 관심종목 선택으로 고정이라 별도 분기 없음.
        return response.user.toDomain()
    }

    private func signInAsDev() async -> User {
        await tokenStore.clearTokens()
        await tokenStore.setDevUserId(AppConfig.devFallbackUserId)
        // 서버에 dev 사용자가 있으면 그 정보를, 없으면 로컬 플레이스홀더를 쓴다(연동 전에도 앱 검증 가능).
        if let dto: UserDTO = try? await api.request(.get("/api/v1/me")) {
            return dto.toDomain()
        }
        return devPlaceholderUser()
    }

    private func devPlaceholderUser() -> User {
        User(id: AppConfig.devFallbackUserId, authProvider: .dev, nickname: "개발자", watchlistCodes: [])
    }

    private func encode(_ value: some Encodable) throws -> Data {
        do {
            return try JSONCoding.encoder().encode(value)
        } catch {
            throw RepositoryError.unknown
        }
    }
}
