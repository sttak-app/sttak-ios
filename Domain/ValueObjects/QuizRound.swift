import Foundation

/// 문항별 채점 흐름(서버가 한 문제씩 내고 채점)의 값 객체들.
/// 정답 인덱스·해설은 제출 전에는 알 수 없다(서버가 채점 후 공개).

/// 아직 풀지 않은 현재 문항. 매핑: GET /quizzes/next 의 question.
struct PendingQuizQuestion: Sendable, Equatable, Identifiable {
    let id: String           // quizId
    let question: String
    let options: [String]    // 4지선다
    let category: String?    // 서버 스펙엔 없어 optional — Mock 픽스처만 제공
}

/// 다음 문항 조회 결과: 새 문항 또는 쿨다운.
enum QuizNextState: Sendable, Equatable {
    case question(PendingQuizQuestion, answeredInCycle: Int, totalInCycle: Int)
    case cooldown(nextAvailableAt: Date?)
}

/// 문항 제출·채점 결과. 매핑: POST /quizzes/{quizId}/submit.
/// 인덱스는 도메인 전반과 동일하게 0-based(서버 1-based는 Live 매퍼가 변환).
struct QuizAnswerResult: Sendable, Equatable {
    let quizId: String
    let selectedIndex: Int
    let correctIndex: Int
    let isCorrect: Bool
    let explanation: String
    let earnedCapital: Money       // 이 문항으로 적립된 자본금(오답이면 0)
    let answeredInCycle: Int
    let totalInCycle: Int
    let completed: Bool            // 이번 사이클(3문제) 완료 여부
    let nextAvailableAt: Date?     // 완료 시 다음 세트 가능 시각(서버 SSOT)
}
