import Foundation

/// AI 회고(서버 LLM). 매도 직후 회고는 점진 생성(스트리밍), 후속 회고는 한 달 뒤 단발.
/// 매핑: 생성=POST /retrospectives (SSE), 후속=POST /trades/{id}/followup.
protocol RetrospectiveRepository: Sendable {
    /// 매도 직후 회고를 점진적으로 스트리밍한다(요약 → 잘한 점 → 함께 볼 점).
    /// 마지막으로 방출되는 값이 완성본이다.
    func generateRetrospective(for trade: Trade) -> AsyncThrowingStream<Retrospective, Error>
    /// 한 달 뒤 후속 회고(서버 스케줄러+APNs, 확정 D8). Mock 단계는 시뮬레이션.
    func generateFollowUp(for trade: Trade) async throws -> FollowUpRetrospective
}
