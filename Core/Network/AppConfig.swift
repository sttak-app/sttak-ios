import Foundation

/// Live 백엔드 접속 설정. Info.plist(project.yml SSOT)에서 읽고, 없으면 dev 기본값을 쓴다.
/// - `STTAK_API_BASE_URL`: 베이스 URL 오버라이드.
/// - `KAKAO_NATIVE_APP_KEY`: 카카오 네이티브 앱 키(xcconfig 주입). 플레이스홀더면 미설정으로 취급.
struct AppConfig: Sendable {
    /// dev ALB(HTTP 전용) — ATS 예외는 project.yml Info에 dev 한정으로 등록되어 있다.
    private static let defaultBaseURLString =
        "http://sttak-dev-alb-709489725.ap-northeast-2.elb.amazonaws.com"
    /// 카카오 키 미설정 상태를 나타내는 플레이스홀더(커밋되는 값). 실제 키는 Configs/Secrets.xcconfig 로컬 교체.
    static let kakaoAppKeyPlaceholder = "KAKAO_APP_KEY_PLACEHOLDER"
    /// 카카오 키가 준비되기 전 개발자 로그인(X-User-Id 헤더)에 쓰는 고정 dev UUID.
    static let devFallbackUserId = "11111111-1111-1111-1111-111111111111"

    let baseURL: URL
    /// 유효한 카카오 네이티브 앱 키(미설정이면 nil).
    let kakaoAppKey: String?

    var isKakaoConfigured: Bool { kakaoAppKey != nil }

    static let `default` = AppConfig(bundle: .main)

    init(bundle: Bundle = .main) {
        let overrideURL = (bundle.object(forInfoDictionaryKey: "STTAK_API_BASE_URL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let overrideURL, !overrideURL.isEmpty, let url = URL(string: overrideURL) {
            self.baseURL = url
        } else if let url = URL(string: Self.defaultBaseURLString) {
            self.baseURL = url
        } else {
            // 도달 불가 방어(상수는 항상 유효한 URL) — 강제 언래핑 금지 규칙 준수.
            self.baseURL = URL(fileURLWithPath: "/")
        }

        let rawKey = (bundle.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let rawKey, !rawKey.isEmpty, rawKey != Self.kakaoAppKeyPlaceholder {
            self.kakaoAppKey = rawKey
        } else {
            self.kakaoAppKey = nil
        }
    }

    init(baseURL: URL, kakaoAppKey: String? = nil) {
        self.baseURL = baseURL
        self.kakaoAppKey = kakaoAppKey
    }
}
