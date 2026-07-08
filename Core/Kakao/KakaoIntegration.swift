import Foundation

// 카카오 SDK 통합. SPM 의존이 빠진 빌드에서도 컴파일되도록 canImport로 가드한다
// (키 미설정/네트워크 불가 환경에서는 dev 로그인 폴백으로 앱 검증 가능).

#if canImport(KakaoSDKAuth) && canImport(KakaoSDKUser) && canImport(KakaoSDKCommon)
@preconcurrency import KakaoSDKAuth
@preconcurrency import KakaoSDKCommon
@preconcurrency import KakaoSDKUser

/// 앱 수명주기 훅(초기화·콜백 URL). SwiftUI onOpenURL에서 호출.
enum KakaoIntegration {
    static let isSDKAvailable = true

    @MainActor
    static func initialize(appKey: String) {
        KakaoSDK.initSDK(appKey: appKey)
    }

    /// kakao{APP_KEY}:// 콜백 처리. 처리했으면 true.
    @MainActor
    static func handleOpenURL(_ url: URL) -> Bool {
        guard AuthApi.isKakaoTalkLoginUrl(url) else { return false }
        return AuthController.handleOpenUrl(url: url)
    }
}

/// 카카오 로그인(카카오톡 앱 우선 → 계정 웹뷰) → OAuth 액세스 토큰.
struct KakaoLoginService: SocialLoginService {
    /// 네이티브 앱 키가 유효하게 주입됐는지(플레이스홀더면 false).
    let isConfigured: Bool

    func kakaoAccessToken() async throws -> String {
        guard isConfigured else {
            throw RepositoryError.validation(message: "카카오 앱 키가 설정되지 않았어요. 개발자 로그인을 사용해 주세요.")
        }
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                let completion: (OAuthToken?, Error?) -> Void = { token, error in
                    if let token {
                        continuation.resume(returning: token.accessToken)
                    } else {
                        continuation.resume(throwing: error ?? RepositoryError.unknown)
                    }
                }
                if UserApi.isKakaoTalkLoginAvailable() {
                    UserApi.shared.loginWithKakaoTalk(completion: completion)
                } else {
                    UserApi.shared.loginWithKakaoAccount(completion: completion)
                }
            }
        }
    }
}

#else

/// SDK 미포함 빌드용 스텁 — 항상 미가용. 개발자 로그인 폴백만 동작한다.
enum KakaoIntegration {
    static let isSDKAvailable = false

    @MainActor
    static func initialize(appKey: String) {}

    @MainActor
    static func handleOpenURL(_ url: URL) -> Bool { false }
}

struct KakaoLoginService: SocialLoginService {
    let isConfigured: Bool

    func kakaoAccessToken() async throws -> String {
        throw RepositoryError.validation(message: "카카오 SDK가 포함되지 않은 빌드예요. 개발자 로그인을 사용해 주세요.")
    }
}

#endif
