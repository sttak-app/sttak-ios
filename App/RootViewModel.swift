import SwiftUI

/// 최상위 라우팅 상태를 구동한다. 무거운 Coordinator 없이 단순 phase 전환.
@MainActor
@Observable
final class RootViewModel {
    enum Phase: Equatable {
        case splash
        case unauthenticated
        case authenticated
    }

    private(set) var phase: Phase = .splash

    private let auth: AuthRepository
    /// 스플래시 표시 시간(핸드오프 splashMs 2100ms).
    private let splashDuration: Duration = .milliseconds(2_100)

    init(auth: AuthRepository) {
        self.auth = auth
    }

    /// 스플래시 → 인증 분기. 앱 시작 시 1회 호출.
    func start() async {
        // 디버그: 런치 인자로 인증 상태에서 시작(탭 셸 확인용).
        if ProcessInfo.processInfo.arguments.contains("-startAuthenticated") {
            _ = try? await auth.signIn(with: .kakao)
        }
        try? await Task.sleep(for: splashDuration)
        await resolveAuth()
    }

    /// 스플래시 탭 시 즉시 전환.
    func skipSplash() async {
        guard phase == .splash else { return }
        await resolveAuth()
    }

    /// 로그인(목업) — 온보딩 placeholder에서 탭 셸로 넘어가 보기 위한 진입점.
    func signInWithMock() async {
        _ = try? await auth.signIn(with: .kakao)
        await resolveAuth()
    }

    private func resolveAuth() async {
        let user = try? await auth.currentUser()
        phase = (user != nil) ? .authenticated : .unauthenticated
    }
}
