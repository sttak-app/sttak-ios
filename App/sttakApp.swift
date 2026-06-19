import SwiftUI

/// 앱 진입점.
///
/// 현재는 최소 스켈레톤으로, 빈 홈 화면(`RootView`)만 표시한다.
/// 의존성 컴포지션 루트(`AppContainer`)·라우팅·기능 화면은 이후 커밋에서 추가한다.
/// (ARCHITECTURE.md §12 커밋 순서 참고)
@main
struct SttakApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
