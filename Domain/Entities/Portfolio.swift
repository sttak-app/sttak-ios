import Foundation

/// 모의투자 포트폴리오. 사용자당 1개 집합체이며 식별자는 소유 User(외부 연결)다 —
/// 중복 ownerId 필드를 두지 않고 값 집합체로 모델링한다.
/// 평가금액·손익은 현재 시세가 필요한 파생값이라 도메인 로직 커밋에서 계산한다(여기선 상태만).
struct Portfolio: Sendable, Equatable {
    let cash: Money            // 현금 (초기 10,000,000원)
    let holdings: [Holding]    // 보유 종목들
}
