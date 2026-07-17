import Foundation

/// 백엔드 공통 응답 봉투: `{"message": string|null, "content": T|null}`.
struct APIEnvelope<Content: Decodable & Sendable>: Decodable, Sendable {
    let message: String?
    let content: Content?

    /// content가 필수인 응답에서 언래핑. null이면 디코딩 실패로 취급한다.
    func requiredContent() throws -> Content {
        guard let content else { throw RepositoryError.decoding }
        return content
    }
}

/// 서버가 content 없이 message만 주는 응답(로그아웃 등) 디코딩용.
struct EmptyContent: Decodable, Sendable {}

/// 앱↔서버 공용 JSON 코딩 규칙. 시간은 ISO8601 UTC 문자열(소수점 초 유무 모두 허용).
enum JSONCoding {
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = parseISO8601(raw) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "ISO8601 날짜가 아님: \(raw)"
            )
        }
        return decoder
    }

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(.iso8601))
        }
        return encoder
    }

    /// ISO8601 파싱 — 소수점 초 포함/미포함 순서로 시도. (포매터는 Sendable한 FormatStyle 사용)
    static func parseISO8601(_ raw: String) -> Date? {
        if let date = try? Date(raw, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
            return date
        }
        return try? Date(raw, strategy: Date.ISO8601FormatStyle())
    }
}
