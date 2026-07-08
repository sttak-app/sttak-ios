import Foundation

/// 백엔드 요청 한 건의 서술. 바디는 미리 인코딩된 Data(Sendable 단순화).
struct APIRequest: Sendable {
    enum Method: String, Sendable {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    var method: Method
    var path: String                     // 예: "/api/v1/me"
    var query: [URLQueryItem] = []
    var body: Data?
    /// 인증 헤더(Bearer 또는 dev X-User-Id)를 붙일지. 로그인/리프레시만 false.
    var requiresAuth: Bool = true

    static func get(_ path: String, query: [URLQueryItem] = []) -> APIRequest {
        APIRequest(method: .get, path: path, query: query)
    }

    static func post(_ path: String, body: Data? = nil, requiresAuth: Bool = true) -> APIRequest {
        APIRequest(method: .post, path: path, body: body, requiresAuth: requiresAuth)
    }

    static func patch(_ path: String, body: Data?) -> APIRequest {
        APIRequest(method: .patch, path: path, body: body)
    }

    static func delete(_ path: String) -> APIRequest {
        APIRequest(method: .delete, path: path)
    }
}

/// Live 백엔드 API 클라이언트.
/// - 봉투(`{message, content}`) 언래핑 + ISO8601 날짜 디코딩.
/// - 인증 헤더 주입: JWT 있으면 `Authorization: Bearer`, 없고 devUserId 있으면 `X-User-Id`(dev 폴백).
/// - 401이면 리프레시 1회(회전 저장) 후 원요청 1회 재시도. 리프레시 실패 시 토큰 비우고 unauthorized.
actor APIClient {
    private let baseURL: URL
    private let tokenStore: any TokenStoring
    private let session: URLSession
    private let decoder = JSONCoding.decoder()
    /// 리프레시 single-flight — 동시 401들이 리프레시를 한 번만 수행하게.
    private var refreshTask: Task<Void, Error>?

    init(
        config: AppConfig,
        tokenStore: any TokenStoring,
        sessionConfiguration: URLSessionConfiguration = .ephemeral
    ) {
        self.baseURL = config.baseURL
        self.tokenStore = tokenStore
        self.session = URLSession(configuration: sessionConfiguration)
    }

    // MARK: 요청 (봉투 언래핑)

    /// content가 필수인 요청. content=null이면 디코딩 에러.
    func request<T: Decodable & Sendable>(_ request: APIRequest) async throws -> T {
        let data = try await performWithRefresh(request)
        return try decodeEnvelope(T.self, from: data).requiredContent()
    }

    /// content=null이 정상인 요청(예: GET /quizzes/last).
    func requestOptional<T: Decodable & Sendable>(_ request: APIRequest) async throws -> T? {
        let data = try await performWithRefresh(request)
        return try decodeEnvelope(T.self, from: data).content
    }

    /// 본문이 필요 없는 요청(204 등).
    func requestVoid(_ request: APIRequest) async throws {
        _ = try await performWithRefresh(request)
    }

    // MARK: SSE

    /// `Accept: text/event-stream` 스트리밍. `event:`/`data:` 줄을 이벤트로 파싱해 흘려보낸다.
    /// 401이면 일반 요청과 동일하게 리프레시 1회 후 재연결한다.
    /// (바이트 시퀀스는 Sendable이 아니므로 접속→파싱을 스트림 내부 Task 하나에서 수행한다)
    nonisolated func serverSentEvents(_ request: APIRequest) -> AsyncThrowingStream<ServerSentEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var didRefresh = false
                    while true {
                        var urlRequest = try await self.makeURLRequest(request)
                        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                        let (bytes, response) = try await self.session.bytes(for: urlRequest)
                        guard let http = response as? HTTPURLResponse else { throw RepositoryError.network }
                        guard (200..<300).contains(http.statusCode) else {
                            if http.statusCode == 401, request.requiresAuth, !didRefresh,
                               await self.tokenStore.refreshToken() != nil {
                                try await self.refreshTokens()
                                didRefresh = true
                                continue
                            }
                            throw Self.error(forStatus: http.statusCode, message: nil)
                        }
                        var parser = SSELineParser()
                        for try await line in bytes.lines {
                            if let event = parser.consume(line: line) {
                                continuation.yield(event)
                            }
                        }
                        continuation.finish()
                        return
                    }
                } catch is CancellationError {
                    continuation.finish()
                } catch let error as RepositoryError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: RepositoryError.network)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: 내부 — 수행/리프레시

    private func performWithRefresh(_ request: APIRequest) async throws -> Data {
        do {
            return try await perform(request)
        } catch RepositoryError.unauthorized where request.requiresAuth {
            // dev 폴백(X-User-Id)은 리프레시 개념이 없으므로 그대로 실패시킨다.
            guard await tokenStore.refreshToken() != nil else { throw RepositoryError.unauthorized }
            try await refreshTokens()
            return try await perform(request)
        }
    }

    private func perform(_ request: APIRequest) async throws -> Data {
        let urlRequest = try await makeURLRequest(request)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw RepositoryError.network
        }
        guard let http = response as? HTTPURLResponse else { throw RepositoryError.network }
        guard (200..<300).contains(http.statusCode) else {
            throw Self.error(forStatus: http.statusCode, message: serverMessage(from: data))
        }
        return data
    }

    /// 리프레시 single-flight: 진행 중이면 합류, 아니면 시작. 실패 시 토큰 폐기 → 인증 에러 표면화.
    private func refreshTokens() async throws {
        if let refreshTask {
            return try await refreshTask.value
        }
        let task = Task<Void, Error> {
            guard let refresh = await self.tokenStore.refreshToken() else {
                throw RepositoryError.unauthorized
            }
            do {
                let body = try JSONCoding.encoder().encode(["refreshToken": refresh])
                let data = try await self.perform(.post("/api/v1/auth/refresh", body: body, requiresAuth: false))
                let pair = try self.decodeEnvelope(TokenPairDTO.self, from: data).requiredContent()
                await self.tokenStore.save(accessToken: pair.accessToken, refreshToken: pair.refreshToken)
            } catch {
                await self.tokenStore.clearTokens()
                throw RepositoryError.unauthorized
            }
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private nonisolated func makeURLRequest(_ request: APIRequest) async throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw RepositoryError.network
        }
        components.path = request.path
        if !request.query.isEmpty {
            components.queryItems = request.query
        }
        guard let url = components.url else { throw RepositoryError.network }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body = request.body {
            urlRequest.httpBody = body
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if request.requiresAuth {
            if let access = await tokenStore.accessToken() {
                urlRequest.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
            } else if let devUserId = await tokenStore.devUserId() {
                // dev 전용 폴백 — 카카오 키 준비 전까지 JWT 없이 인증(백엔드 dev 환경 한정).
                urlRequest.setValue(devUserId, forHTTPHeaderField: "X-User-Id")
            }
        }
        return urlRequest
    }

    private func decodeEnvelope<T: Decodable & Sendable>(_ type: T.Type, from data: Data) throws -> APIEnvelope<T> {
        do {
            return try decoder.decode(APIEnvelope<T>.self, from: data)
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.decoding
        }
    }

    /// 에러 응답의 봉투 message(있으면).
    private func serverMessage(from data: Data) -> String? {
        (try? decoder.decode(APIEnvelope<EmptyContent>.self, from: data))?.message
    }

    private static func error(forStatus status: Int, message: String?) -> RepositoryError {
        switch status {
        case 400: return .validation(message: message ?? "요청이 올바르지 않아요.")
        case 401: return .unauthorized
        case 404: return .notFound
        case 500...: return .server(message: message)
        default: return .unknown
        }
    }
}

/// 토큰 회전 응답: POST /auth/refresh → {accessToken, refreshToken}.
struct TokenPairDTO: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
}
