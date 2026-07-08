import XCTest
@testable import sttak

/// APIClient 인증 흐름 — 401 → 리프레시(회전 저장) → 원요청 재시도 / 리프레시 실패 → 토큰 폐기.
/// 네트워크 없이 URLProtocol 스텁으로 검증한다.
final class APIClientAuthTests: XCTestCase {

    private func makeClient(tokenStore: InMemoryTokenStore) -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return APIClient(
            config: AppConfig(baseURL: StubURLProtocol.baseURL),
            tokenStore: tokenStore,
            sessionConfiguration: configuration
        )
    }

    override func tearDown() {
        StubURLProtocol.reset()
        super.tearDown()
    }

    func testExpiredAccess_refreshesOnce_andRetriesOriginal() async throws {
        let tokenStore = InMemoryTokenStore(access: "expired-access", refresh: "refresh-1")
        let client = makeClient(tokenStore: tokenStore)

        StubURLProtocol.setHandler { request in
            let auth = request.value(forHTTPHeaderField: "Authorization")
            switch (request.url?.path ?? "", auth) {
            case ("/api/v1/me", "Bearer expired-access"):
                return (401, #"{"message":"만료","content":null}"#)
            case ("/api/v1/auth/refresh", _):
                // 리프레시는 인증 헤더 없이 refreshToken 바디만.
                return (200, #"{"message":null,"content":{"accessToken":"access-2","refreshToken":"refresh-2"}}"#)
            case ("/api/v1/me", "Bearer access-2"):
                return (200, #"{"message":null,"content":{"id":"u1","nickname":"투자초보","authProvider":"KAKAO","watchlistCodes":["005930"]}}"#)
            default:
                return (500, #"{"message":"unexpected","content":null}"#)
            }
        }

        let user: UserDTO = try await client.request(.get("/api/v1/me"))
        XCTAssertEqual(user.id, "u1")

        // 회전된 페어가 저장되고, 총 3회 호출(원요청 → 리프레시 → 재시도).
        let access = await tokenStore.accessToken()
        let refresh = await tokenStore.refreshToken()
        XCTAssertEqual(access, "access-2")
        XCTAssertEqual(refresh, "refresh-2")
        XCTAssertEqual(StubURLProtocol.requestedPaths(), ["/api/v1/me", "/api/v1/auth/refresh", "/api/v1/me"])
    }

    func testRefreshFailure_clearsTokens_andSurfacesAuthError() async throws {
        let tokenStore = InMemoryTokenStore(access: "expired-access", refresh: "bad-refresh")
        let client = makeClient(tokenStore: tokenStore)

        StubURLProtocol.setHandler { request in
            switch request.url?.path ?? "" {
            case "/api/v1/me":
                return (401, #"{"message":"만료","content":null}"#)
            case "/api/v1/auth/refresh":
                return (401, #"{"message":"리프레시 만료","content":null}"#)
            default:
                return (500, #"{"message":"unexpected","content":null}"#)
            }
        }

        do {
            let _: UserDTO = try await client.request(.get("/api/v1/me"))
            XCTFail("unauthorized를 기대")
        } catch let error as RepositoryError {
            XCTAssertEqual(error, .unauthorized)
        }

        // 재로그인 유도를 위해 토큰은 폐기된다. 재시도는 없다(리프레시 1회 실패로 종료).
        let access = await tokenStore.accessToken()
        let refresh = await tokenStore.refreshToken()
        XCTAssertNil(access)
        XCTAssertNil(refresh)
        XCTAssertEqual(StubURLProtocol.requestedPaths(), ["/api/v1/me", "/api/v1/auth/refresh"])
    }

    func testNoJWT_withDevUserId_sendsXUserIdHeader() async throws {
        let tokenStore = InMemoryTokenStore(access: nil, refresh: nil, devUserId: "dev-uuid")
        let client = makeClient(tokenStore: tokenStore)

        StubURLProtocol.setHandler { request in
            guard request.value(forHTTPHeaderField: "X-User-Id") == "dev-uuid",
                  request.value(forHTTPHeaderField: "Authorization") == nil else {
                return (401, #"{"message":"no auth","content":null}"#)
            }
            return (200, #"{"message":null,"content":{"id":"dev-uuid","nickname":"개발자","authProvider":"DEV","watchlistCodes":[]}}"#)
        }

        let user: UserDTO = try await client.request(.get("/api/v1/me"))
        XCTAssertEqual(user.nickname, "개발자")
    }
}

// MARK: - 테스트 더블

/// 인메모리 토큰 저장(Keychain 미사용 — 테스트 결정성).
actor InMemoryTokenStore: TokenStoring {
    private var access: String?
    private var refresh: String?
    private var devId: String?

    init(access: String? = nil, refresh: String? = nil, devUserId: String? = nil) {
        self.access = access
        self.refresh = refresh
        self.devId = devUserId
    }

    func accessToken() -> String? { access }
    func refreshToken() -> String? { refresh }
    func devUserId() -> String? { devId }

    func save(accessToken: String, refreshToken: String) {
        access = accessToken
        refresh = refreshToken
    }

    func setDevUserId(_ id: String?) { devId = id }

    func clearTokens() {
        access = nil
        refresh = nil
    }
}

/// URLSession 요청을 가로채는 스텁. 핸들러/기록은 락으로 보호(테스트는 직렬 실행 가정).
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    static let baseURL = URL(string: "http://stub.test") ?? URL(fileURLWithPath: "/")
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: (@Sendable (URLRequest) -> (Int, String))?
    nonisolated(unsafe) private static var paths: [String] = []

    static func setHandler(_ new: @escaping @Sendable (URLRequest) -> (Int, String)) {
        lock.lock(); defer { lock.unlock() }
        handler = new
        paths = []
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        handler = nil
        paths = []
    }

    static func requestedPaths() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return paths
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let request = self.request
        let (status, body): (Int, String)
        Self.lock.lock()
        Self.paths.append(request.url?.path ?? "")
        let currentHandler = Self.handler
        Self.lock.unlock()

        // URLProtocol은 httpBody를 스트림으로 바꾸므로 바디 검증은 헤더/경로 기준으로 한다.
        (status, body) = currentHandler?(request) ?? (500, "{}")

        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"]) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
