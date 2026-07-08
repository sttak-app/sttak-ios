import Foundation

/// 퀴즈 한 문제(4지선다 단일 정답).
struct QuizQuestion: Sendable, Equatable {
    let question: String
    let options: [String]    // 4지선다
    let answerIndex: Int     // 정답 인덱스 (options 기준)
    let explanation: String  // 해설
    let category: String     // 카테고리(차트·지표 / 가치 평가 / 투자 원칙 등 — LLM 생성 개방형)
}
