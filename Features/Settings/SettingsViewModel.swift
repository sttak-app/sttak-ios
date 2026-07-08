import SwiftUI

/// 설정. 알림 토글은 Mock에선 상태 저장만(UserDefaults) — 실제 발송은 Live(APNs).
/// 로그아웃/회원탈퇴는 AuthRepository로 위임하고, 완료 시 onSignedOut으로 로그인 복귀를 알린다.
@MainActor
@Observable
final class SettingsViewModel {
    enum Toggle: String {
        case followUpRetro = "settings.notify.followUpRetro"
        case quizReminder = "settings.notify.quizReminder"
        case rankingChange = "settings.notify.rankingChange"
    }

    var followUpRetroEnabled: Bool { didSet { save(.followUpRetro, followUpRetroEnabled) } }
    var quizReminderEnabled: Bool { didSet { save(.quizReminder, quizReminderEnabled) } }
    var rankingChangeEnabled: Bool { didSet { save(.rankingChange, rankingChangeEnabled) } }

    private(set) var isProcessing = false
    let appVersion: String

    private let auth: AuthRepository
    private let defaults: UserDefaults

    init(auth: AuthRepository, defaults: UserDefaults = .standard) {
        self.auth = auth
        self.defaults = defaults
        // 기본값 켜짐(처음 설치). didSet은 init 중 발동하지 않음.
        followUpRetroEnabled = defaults.object(forKey: Toggle.followUpRetro.rawValue) as? Bool ?? true
        quizReminderEnabled = defaults.object(forKey: Toggle.quizReminder.rawValue) as? Bool ?? true
        rankingChangeEnabled = defaults.object(forKey: Toggle.rankingChange.rawValue) as? Bool ?? false
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.9"
        appVersion = version
    }

    /// 로그아웃(가역). 성공 시 true → 호출부가 onSignedOut.
    func logout() async -> Bool {
        isProcessing = true
        defer { isProcessing = false }
        do { try await auth.signOut(); return true } catch { return false }
    }

    /// 회원탈퇴(영구 삭제). 성공 시 true.
    func deleteAccount() async -> Bool {
        isProcessing = true
        defer { isProcessing = false }
        do { try await auth.deleteAccount(); return true } catch { return false }
    }

    private func save(_ key: Toggle, _ value: Bool) {
        defaults.set(value, forKey: key.rawValue)
    }
}
