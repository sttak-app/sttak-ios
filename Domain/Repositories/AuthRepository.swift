import Foundation

/// 인증. 소셜 토큰 → 백엔드 검증 → 자체 JWT 발급(확정 B4)을 추상화한다.
/// 매핑: signIn=POST /auth/login, currentUser=GET /me, signOut=POST /auth/logout.
protocol AuthRepository: Sendable {
    /// 소셜 로그인. 성공 시 로그인 사용자 반환.
    func signIn(with provider: AuthProvider) async throws -> User
    /// 현재 로그인 사용자(없으면 nil).
    func currentUser() async throws -> User?
    /// 관심종목 갱신(온보딩 완료 등). 매핑: PATCH /me/watchlist.
    func updateWatchlist(_ codes: [String]) async throws -> User
    /// 로그아웃(가역). JWT·Keychain 비움. 서버 데이터는 유지.
    func signOut() async throws
    /// 회원탈퇴(계정·데이터 영구 삭제, 복구 불가). 매핑: DELETE /me.
    /// 메모: Sign in with Apple 토큰 revoke는 **서버(Spring)** 가 Apple REST API로 수행한다(클라는 호출만).
    func deleteAccount() async throws
}
