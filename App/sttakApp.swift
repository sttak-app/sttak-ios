import SwiftUI

/// 앱 진입점. 컴포지션 루트(`AppContainer`)를 1회 생성해 Environment로 주입하고,
/// 최상위 라우팅(`RootView`)을 띄운다. 카카오 SDK 초기화·로그인 콜백 URL도 여기서 처리한다.
@main
struct SttakApp: App {
    @State private var container = AppContainer()

    init() {
        // 카카오 키가 유효할 때만 SDK 초기화(플레이스홀더면 dev 로그인 폴백 사용).
        if let appKey = AppConfig.default.kakaoAppKey {
            KakaoIntegration.initialize(appKey: appKey)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.container, container)
                .onOpenURL { url in
                    // kakao{APP_KEY}:// 로그인 콜백.
                    _ = KakaoIntegration.handleOpenURL(url)
                }
        }
    }
}
