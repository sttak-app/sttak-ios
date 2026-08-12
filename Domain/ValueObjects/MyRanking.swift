import Foundation

/// 서버가 산출한 내 순위 요약(GET /ranking/me). GET /me/asset과 일관.
struct MyRanking: Sendable, Equatable {
    let rank: Int
    let assetValue: Money    // 내 보유 자산(현금 + 보유 평가액)
    let totalCount: Int      // 전체 리더보드 인원
    let topPercent: Int      // 상위 %(작을수록 상위)
    let returnRate: Double    // 시작 자본 대비 수익률(%)
}
