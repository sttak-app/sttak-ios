import Foundation

/// GET /api/v1/quizzes/next 응답.
struct QuizNextDTO: Decodable, Sendable {
    struct Question: Decodable, Sendable {
        let quizId: Int
        let question: String
        let options: [String]
    }

    let cooldown: Bool
    let question: Question?
    let answeredInCycle: Int
    let totalInCycle: Int
    let nextAvailableAt: String?   // 서버 LocalDateTime(오프셋 없음) → String으로 받아 관대하게 파싱

    func toDomain() throws -> QuizNextState {
        if cooldown {
            return .cooldown(nextAvailableAt: JSONCoding.parseKSTDate(nextAvailableAt))
        }
        guard let question else { throw RepositoryError.decoding }
        return .question(
            PendingQuizQuestion(
                id: String(question.quizId),
                question: question.question,
                options: question.options,
                category: nil // 서버 스펙에 카테고리 없음
            ),
            answeredInCycle: answeredInCycle,
            totalInCycle: totalInCycle
        )
    }
}

/// POST /api/v1/quizzes/{quizId}/submit — 요청은 1-based 선택지, 응답도 1-based 정답.
struct QuizSubmitRequestDTO: Encodable, Sendable {
    let selectedChoice: Int
}

struct QuizSubmitResponseDTO: Decodable, Sendable {
    let quizId: Int
    let selectedChoice: Int
    let correctChoice: Int
    let isCorrect: Bool
    let explanation: String
    let earnedCapital: Int
    let answeredInCycle: Int
    let totalInCycle: Int
    let completed: Bool
    let nextAvailableAt: String?   // 서버 LocalDateTime(오프셋 없음)

    /// 서버 1-based choice → 도메인 0-based index.
    func toDomain() -> QuizAnswerResult {
        QuizAnswerResult(
            quizId: String(quizId),
            selectedIndex: selectedChoice - 1,
            correctIndex: correctChoice - 1,
            isCorrect: isCorrect,
            explanation: explanation,
            earnedCapital: .krw(earnedCapital),
            answeredInCycle: answeredInCycle,
            totalInCycle: totalInCycle,
            completed: completed,
            nextAvailableAt: JSONCoding.parseKSTDate(nextAvailableAt)
        )
    }
}

/// GET /api/v1/quizzes/last 응답(없으면 content=null).
struct QuizLastDTO: Decodable, Sendable {
    let takenAt: String   // 서버 LocalDateTime(오프셋 없음)
    let correctCount: Int
    let earnedCapital: Int

    func toDomain() -> QuizCompletion {
        QuizCompletion(
            takenAt: JSONCoding.parseKSTDate(takenAt) ?? Date(),
            correctCount: correctCount,
            earnedCapital: .krw(earnedCapital)
        )
    }
}
