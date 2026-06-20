import Foundation

/// 퀴즈(서버 LLM 배치 생성 + 결과 기록). 채점·보상 규칙은 ScoreQuizAndAwardCapital UseCase가 담당.
/// 매핑: current=GET /quiz/current, last=GET /quiz/last, record=POST /quiz/result.
protocol QuizRepository: Sendable {
    /// 현재 풀 수 있는 퀴즈 세트(3문제).
    func currentQuizSet() async throws -> QuizSet
    /// 마지막으로 푼 결과(쿨다운 판정·지난 세트 요약). 없으면 nil.
    func lastCompletion() async throws -> QuizCompletion?
    /// 결과 기록(쿨다운 설정 + 지난 세트 보관). 자본금은 PortfolioRepository에서.
    func recordResult(correctCount: Int, earnedCapital: Money, takenAt: Date) async throws

    #if DEBUG
    /// 디버그: 쿨다운 초기화(반복 테스트용). release엔 없음.
    func debugClearCooldown() async throws
    #endif
}
