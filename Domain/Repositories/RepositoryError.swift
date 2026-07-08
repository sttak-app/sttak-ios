import Foundation

/// 모든 Repository가 공유하는 도메인 에러. Mock과 (나중)Live가 동일한 에러를 던진다.
/// 향후 Spring 백엔드 응답에 매핑: notFound=404, unauthorized=401, validation=400,
/// server=5xx, network=전송 실패, decoding=응답 파싱 실패.
enum RepositoryError: Error, Sendable, Equatable {
    case notFound
    case unauthorized
    case network
    case server(message: String?)
    case decoding
    case validation(message: String)
    case unknown
}
