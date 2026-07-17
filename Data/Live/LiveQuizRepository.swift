import Foundation

/// 퀴즈 Live: 서버가 문항별 출제·채점·보상·쿨다운의 SSOT.
/// 매핑: GET /quizzes/next, POST /quizzes/{id}/submit, GET /quizzes/last.
struct LiveQuizRepository: QuizRepository {
    let api: APIClient
    /// 포트폴리오가 아직 Mock인 동안 서버 적립을 로컬 현금에 미러링(자본금 배너 일관성).
    /// 포트폴리오 Live 전환 시 제거 — 서버가 이미 적립하므로 이 미러는 이중 적립이 된다.
    let localCapitalMirror: (any PortfolioRepository)?

    init(api: APIClient, localCapitalMirror: (any PortfolioRepository)? = nil) {
        self.api = api
        self.localCapitalMirror = localCapitalMirror
    }

    func nextQuestion() async throws -> QuizNextState {
        let dto: QuizNextDTO = try await api.request(.get("/api/v1/quizzes/next"))
        return try dto.toDomain()
    }

    func submitAnswer(quizId: String, selectedIndex: Int) async throws -> QuizAnswerResult {
        let body: Data
        do {
            // 도메인 0-based → 서버 1-based.
            body = try JSONCoding.encoder().encode(QuizSubmitRequestDTO(selectedChoice: selectedIndex + 1))
        } catch {
            throw RepositoryError.unknown
        }
        let dto: QuizSubmitResponseDTO = try await api.request(
            .post("/api/v1/quizzes/\(quizId)/submit", body: body)
        )
        let result = dto.toDomain()
        if result.earnedCapital.amount > 0 {
            try? await localCapitalMirror?.creditCash(result.earnedCapital)
        }
        return result
    }

    func lastCompletion() async throws -> QuizCompletion? {
        let dto: QuizLastDTO? = try await api.requestOptional(.get("/api/v1/quizzes/last"))
        return dto?.toDomain()
    }

    #if DEBUG
    func debugClearCooldown() async throws {
        // 서버가 쿨다운 SSOT — 클라이언트에서 초기화 불가(no-op).
    }
    #endif
}
