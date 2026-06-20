import Foundation

/// 퀴즈(서버 LLM 배치 생성 + 채점·적립). 적립은 모의 자본금으로 연결(확정 C5: Mock=로컬).
/// 매핑: current=GET /quiz/current, submit=POST /quiz/{id}/submit.
protocol QuizRepository: Sendable {
    /// 현재 풀 수 있는 퀴즈 세트(3문제).
    func currentQuizSet() async throws -> QuizSet
    /// 선택한 답안들을 제출 → 채점·자본금 적립 → 결과가 반영된 세트 반환.
    func submit(quizSetID: String, selectedAnswers: [Int]) async throws -> QuizSet
}
