import Foundation

/// 챗봇 메시지 발화 주체.
enum ChatRole: Sendable, Equatable {
    case user
    case assistant
}

/// 챗봇 진입 맥락. 서버가 답변 근거를 찾을 수 있도록 "무엇에 대한 질문인지" 식별자를 함께 나른다.
enum ChatContext: Sendable, Equatable {
    /// 뉴스 상세에서. `newsId`는 서버 뉴스 응답(NewsCardResponse)에 id가 없어 아직 채울 수 없다.
    case news(stockCode: String?, newsId: Int?)
    /// 차트 구간에서.
    case chartSegment(stockCode: String)
    /// 자유 질문 — 특정 종목/뉴스에 묶이지 않는다.
    case free

    /// 질문이 가리키는 종목코드(뉴스·차트 구간 공통). 자유 질문이면 nil.
    var stockCode: String? {
        switch self {
        case let .news(stockCode, _): return stockCode
        case let .chartSegment(stockCode): return stockCode
        case .free: return nil
        }
    }

    /// 질문이 가리키는 뉴스 식별자. 뉴스 맥락이 아니거나 서버가 id를 주지 않으면 nil.
    var newsId: Int? {
        if case let .news(_, newsId) = self { return newsId }
        return nil
    }
}

/// 챗봇 메시지 한 개. ChatSession의 구성 요소.
struct ChatMessage: Sendable, Equatable {
    let role: ChatRole
    let text: String
    let timestamp: Date
}
