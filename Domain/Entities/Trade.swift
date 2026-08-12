import Foundation

/// 매매 종류.
enum TradeType: Sendable, Equatable {
    case buy   // 매수
    case sell  // 매도
}

/// 주문 상태(ADR-011: 접수→익일 배치 정산). PENDING 접수 → 다음 영업일 FILLED/REJECTED, 취소 시 CANCELLED.
enum TradeStatus: Sendable, Equatable {
    case pending    // 접수 완료, 다음 영업일 체결 대기
    case filled     // 체결됨
    case rejected   // 거부됨(현금·보유 부족 등)
    case cancelled  // 사용자가 취소(PENDING만 가능)
}

/// 체결 기준가. 매수=주문일 시가(OPEN), 매도=주문일 종가(CLOSE).
enum FillBasis: Sendable, Equatable {
    case open   // 시가(매수)
    case close  // 종가(매도)
}

/// 매수/매도 주문 한 건. 접수 시 PENDING이고, 정산 후 체결 정보·매도 회고가 채워진다.
/// (서버 sttak_trades / GET /trades 계약과 교차검증)
struct Trade: Sendable, Equatable, Identifiable {
    let id: String
    let type: TradeType
    let stockCode: String
    let quantity: Int
    let rationale: TradeRationale      // 근거(필수)
    let status: TradeStatus
    let orderedAt: Date                // 접수 시각
    let tradingDate: Date?             // 정산 기준일 D(익영업일). LocalDate → KST 자정
    let fillBasis: FillBasis?          // 체결 기준(매수=시가/매도=종가)
    let referencePrice: Money?         // 참고가(T-1 종가). 실제 체결가와 다를 수 있음
    let filledPrice: Money?            // 체결가(주당) — FILLED만
    let filledAt: Date?                // 체결 시각 — FILLED만
    let rejectedReason: String?        // 거부 사유 — REJECTED만
    let realizedProfit: Money?         // 매도 실현손익 — SELL FILLED만
    let retrospective: Retrospective?  // 매도 회고(서버 생성) — SELL FILLED + 생성 시
}
