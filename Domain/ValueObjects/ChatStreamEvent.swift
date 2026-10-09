import Foundation

/// 챗봇 답변 진행 단계. 서버 가드레일 파이프라인(생성 → 다듬기 → 검수)의 현재 위치로,
/// 검증이 재시도되면 refining/verifying 이 여러 번 올 수 있다 — 마지막 값만 표시하면 된다.
enum ChatStage: String, Sendable, Equatable {
    case generating
    case refining
    case verifying
}

/// 챗봇 스트림 이벤트. 2026-09-24 서버 계약: 본문을 조각(token)으로 흘리지 않고
/// 진행 단계(stage)를 0회 이상 보낸 뒤 완성 본문(answer)을 한 번에 보낸다.
enum ChatStreamEvent: Sendable, Equatable {
    case stage(ChatStage)
    case answer(String)
}
