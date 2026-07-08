import Foundation

/// 한 달 뒤 후속 회고. 매도 결정 vs 한 달 뒤 실제 주가 비교(두 번째 피드백).
/// 비교 코멘트는 서버(LLM)가 생성한 per-instance 데이터다(정적 표현 카피 아님).
struct FollowUpRetrospective: Sendable, Equatable {
    let evaluatedAt: Date        // 후속 회고 평가 시점 (약 한 달 뒤)
    let priceAtFollowUp: Money   // 그 시점 실제 주가
    let comparisonText: String   // 당시 결정과의 비교 코멘트
}
