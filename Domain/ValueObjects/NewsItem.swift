import Foundation

/// 뉴스/공시 한 건. (sttak-data.js 종목별 `news[]` 구조와 교차검증)
/// 식별자가 필요해지면 Entity로 승격(서버 도입 시 결정) — 현재는 VO.
struct NewsItem: Sendable, Equatable {
    let sentiment: Sentiment
    let title: String
    let easy: String          // 쉬운 한 줄 요약 (easy)
    let summary: String       // 100자 내외 풀이 (summary)
    let whyPoints: [String]   // 왜 중요한가요 불릿 (why[])
    let reason: String        // 부드러운 호재/중립/악재 판단 (reason)
    let terms: [Term]         // 알아두면 좋은 용어
    let source: String        // 출처
    let publishedAt: Date     // 게시 시각 ("1시간 전" 등 상대 표기는 표현 계층)
    let originalURL: URL?      // 원문 링크 (mock엔 없을 수 있어 optional)
    let lead: String          // 원문 미리보기 (lead)
}
