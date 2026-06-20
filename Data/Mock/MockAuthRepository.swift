import Foundation

/// 인증 Mock. 로그인 시 대표 사용자를 만들어 공유 store에 보관한다.
/// 닉네임은 핸드오프에 지정된 값이 없어 Mock 플레이스홀더("투자초보")를 사용한다.
/// 관심종목 기본값은 Prototype 기존-유저 데모의 코드(005930/035420/035720)를 따른다.
struct MockAuthRepository: AuthRepository {
    let store: MockLocalStore

    func signIn(with provider: AuthProvider) async throws -> User {
        let user = User(
            id: "mock-user",
            authProvider: provider,
            nickname: "투자초보",
            watchlistCodes: ["005930", "035420", "035720"]
        )
        await store.setUser(user)
        return user
    }

    func currentUser() async throws -> User? {
        await store.user
    }

    func updateWatchlist(_ codes: [String]) async throws -> User {
        guard let current = await store.user else { throw RepositoryError.unauthorized }
        let updated = User(
            id: current.id,
            authProvider: current.authProvider,
            nickname: current.nickname,
            watchlistCodes: codes
        )
        await store.setUser(updated)
        return updated
    }

    func signOut() async throws {
        await store.setUser(nil)
    }
}
