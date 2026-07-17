import Foundation

/// 퀴즈(서버가 문항별로 출제·채점·보상하는 SSOT). 쿨다운 판정도 서버 응답을 따른다.
/// 매핑: next=GET /quizzes/next, submit=POST /quizzes/{id}/submit, last=GET /quizzes/last.
/// Mock은 동일 인터페이스를 로컬 상태(6시간 쿨다운·문항 픽스처)로 재현한다.
protocol QuizRepository: Sendable {
    /// 다음 문항(진행 중 사이클 이어풀기 포함) 또는 쿨다운 상태.
    func nextQuestion() async throws -> QuizNextState
    /// 문항 제출 → 서버 채점 결과(정답·해설·적립 자본금·완료 여부).
    func submitAnswer(quizId: String, selectedIndex: Int) async throws -> QuizAnswerResult
    /// 마지막으로 푼 결과(쿨다운 화면의 지난 세트 요약). 없으면 nil.
    func lastCompletion() async throws -> QuizCompletion?

    #if DEBUG
    /// 디버그: 쿨다운 초기화(반복 테스트용). release엔 없음. Live는 서버가 SSOT라 no-op.
    func debugClearCooldown() async throws
    #endif
}
