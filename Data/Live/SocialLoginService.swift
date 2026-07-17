import Foundation

/// 소셜 SDK에서 OAuth 토큰을 얻는 추상화. LiveAuthRepository가 백엔드 교환 전에 사용한다.
/// (SDK 의존을 Data 계층 밖으로 밀어내 테스트·키 미설정 빌드를 가능하게)
protocol SocialLoginService: Sendable {
    /// 카카오 로그인(카카오톡 앱 우선, 없으면 계정 웹뷰) → OAuth 액세스 토큰.
    func kakaoAccessToken() async throws -> String
}
