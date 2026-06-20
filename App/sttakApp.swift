import SwiftUI

/// 앱 진입점. 컴포지션 루트(`AppContainer`)를 1회 생성해 Environment로 주입하고,
/// 최상위 라우팅(`RootView`)을 띄운다. 기능 화면은 이후 커밋에서 추가한다.
@main
struct SttakApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.container, container)
        }
    }
}
