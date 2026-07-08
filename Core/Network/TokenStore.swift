import Foundation
import Security

/// 인증 자격(액세스/리프레시 토큰 + dev 폴백 사용자 ID) 보관 추상화.
/// APIClient·LiveAuthRepository가 공유한다. 테스트는 인메모리 구현으로 대체.
protocol TokenStoring: Sendable {
    func accessToken() async -> String?
    func refreshToken() async -> String?
    /// JWT 없이 `X-User-Id` 헤더로 인증하는 dev 전용 폴백 사용자 ID(카카오 키 준비 전).
    func devUserId() async -> String?
    func save(accessToken: String, refreshToken: String) async
    func setDevUserId(_ id: String?) async
    func clearTokens() async
}

/// Keychain 기반 토큰 저장(확정 B4: JWT는 Keychain, UserDefaults 금지) + 인메모리 캐시.
/// dev 폴백 ID도 같은 Keychain 서비스에 함께 보관해 재실행 간 유지한다.
actor KeychainTokenStore: TokenStoring {
    private enum Key: String {
        case access = "accessToken"
        case refresh = "refreshToken"
        case devUserId = "devUserId"
    }

    private let keychain: KeychainStorage
    /// 인메모리 캐시. `loaded` 전에는 Keychain을 1회 읽어 채운다.
    private var cache: [Key.RawValue: String] = [:]
    private var loaded = false

    init(service: String = "com.sttak.app.auth") {
        self.keychain = KeychainStorage(service: service)
    }

    func accessToken() -> String? { value(for: .access) }
    func refreshToken() -> String? { value(for: .refresh) }
    func devUserId() -> String? { value(for: .devUserId) }

    func save(accessToken: String, refreshToken: String) {
        set(accessToken, for: .access)
        set(refreshToken, for: .refresh)
    }

    func setDevUserId(_ id: String?) {
        if let id {
            set(id, for: .devUserId)
        } else {
            remove(.devUserId)
        }
    }

    func clearTokens() {
        remove(.access)
        remove(.refresh)
    }

    // MARK: 내부

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        for key in [Key.access, .refresh, .devUserId] {
            if let stored = keychain.read(account: key.rawValue) {
                cache[key.rawValue] = stored
            }
        }
    }

    private func value(for key: Key) -> String? {
        loadIfNeeded()
        return cache[key.rawValue]
    }

    private func set(_ value: String, for key: Key) {
        loadIfNeeded()
        cache[key.rawValue] = value
        keychain.write(value, account: key.rawValue)
    }

    private func remove(_ key: Key) {
        loadIfNeeded()
        cache[key.rawValue] = nil
        keychain.delete(account: key.rawValue)
    }
}

/// kSecClassGenericPassword 최소 래퍼. 실패는 조용히 무시(캐시가 세션 내 일관성 보장,
/// 시뮬레이터·테스트 환경에서 Keychain이 제한될 수 있음).
struct KeychainStorage: Sendable {
    let service: String

    func read(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func write(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        var query = baseQuery(account: account)
        // upsert: 있으면 갱신, 없으면 추가.
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
