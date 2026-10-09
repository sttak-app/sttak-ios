import Foundation

/// 진행 단계 → 대기 문구. 챗봇(ChatView)·뉴스 상세 AI 탭이 함께 쓴다.
/// 판단을 단정하지 않는 담백한 진행 표현만 사용한다(핸드오프 톤).
extension ChatStage {
    var displayText: String {
        switch self {
        case .generating: return "답변을 만들고 있어요"
        case .refining: return "표현을 다듬고 있어요"
        case .verifying: return "한 번 더 확인하고 있어요"
        }
    }
}
