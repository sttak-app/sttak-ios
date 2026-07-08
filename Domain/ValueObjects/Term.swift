import Foundation

/// 용어 풀이 카드. (sttak-data.js `terms`: { term, def })
struct Term: Sendable, Equatable {
    let term: String        // 용어
    let definition: String  // 쉬운 정의 (def)
}
