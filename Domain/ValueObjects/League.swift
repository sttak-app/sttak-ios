import Foundation

/// 랭킹 등급(리그). 포인트 임계값으로 산출하는 로직은 도메인 로직 커밋에서 다룬다.
/// 선언 순서가 등급 순서이며, 그 순서로 비교 가능하다.
enum League: Sendable, Equatable, CaseIterable, Comparable {
    case bronze
    case silver
    case gold
    case platinum
    case diamond

    /// 낮을수록 하위 등급.
    private var order: Int {
        switch self {
        case .bronze: return 0
        case .silver: return 1
        case .gold: return 2
        case .platinum: return 3
        case .diamond: return 4
        }
    }

    static func < (lhs: League, rhs: League) -> Bool {
        lhs.order < rhs.order
    }
}
