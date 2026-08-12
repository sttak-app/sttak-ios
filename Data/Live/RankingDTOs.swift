import Foundation

/// GET /api/v1/ranking 응답 — 보유 자산 상위 100 리더보드 + 갱신 시각.
/// updatedAt은 서버가 LocalDateTime(오프셋 없음)으로 주므로 관대하게 String으로 받는다:
/// JSONCoding의 ISO8601 전략은 오프셋을 요구해, Date로 바로 받으면 응답 전체 디코딩이 깨진다.
struct RankingSnapshotDTO: Decodable, Sendable {
    let updatedAt: String?
    let entries: [RankingEntryDTO]

    func toDomain() -> RankingSnapshot {
        RankingSnapshot(
            id: "ranking",
            entries: entries.map { $0.toDomain() },
            updatedAt: JSONCoding.parseKSTDate(updatedAt) ?? Date()
        )
    }
}

/// GET /api/v1/ranking/me 응답 — 서버가 산출한 내 순위 요약.
struct MyRankingDTO: Decodable, Sendable {
    let rank: Int
    let assetValue: Int
    let totalCount: Int
    let topPercent: Int
    let profitRate: Double

    func toDomain() -> MyRanking {
        MyRanking(
            rank: rank,
            assetValue: .krw(assetValue),
            totalCount: totalCount,
            topPercent: topPercent,
            returnRate: profitRate
        )
    }
}

/// GET /api/v1/ranking 리더보드 한 행. rank·assetValue는 서버 long(정수 KRW).
struct RankingEntryDTO: Decodable, Sendable {
    let rank: Int
    let nickname: String
    let assetValue: Int
    let profitRate: Double   // 서버 제공. RankingEntry엔 필드가 없어 표시용 수익률은 뷰모델이 동일 공식으로 계산.

    func toDomain() -> RankingEntry {
        RankingEntry(
            rank: rank,
            nickname: nickname,
            assetValue: .krw(assetValue),
            rankChange: 0,          // 서버는 1시간 전 대비 변동을 주지 않음 → 0(유지)로 표시
            isCurrentUser: false    // /ranking은 내 행을 표시하지 않음 → 내 순위는 별도 합성(RankingPlacement)
        )
    }
}
