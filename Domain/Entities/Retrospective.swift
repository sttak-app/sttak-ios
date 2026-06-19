import Foundation

/// 매도 직후 AI 회고. 한 매도 건에 종속되며, 한 달 뒤 후속 회고가 이어 붙는다.
/// 잘한 부분/함께 볼 부분은 서버(LLM)가 생성한 per-instance 데이터다.
struct Retrospective: Sendable, Equatable, Identifiable {
    let id: String
    let summaryLine: String                  // 한 줄 요약 (sumLine)
    let goodPoints: [String]                 // 잘한 부분
    let watchPoints: [String]                // 함께 보면 좋은 부분
    let isPartialSell: Bool                   // 일부만 매도 여부
    let createdAt: Date                       // 매도 직후 회고 생성 시각
    let followUp: FollowUpRetrospective?      // 한 달 뒤 후속 (도착 전 nil)
}
