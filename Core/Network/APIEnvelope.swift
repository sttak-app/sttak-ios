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

    /// 서버 LocalDate("yyyy-MM-dd")·오프셋 없는 LocalDateTime을 KST 기준 Date로 관대하게 파싱.
    /// (백엔드 tradingDate·ranking updatedAt은 오프셋이 없어 ISO8601 전략만으론 깨진다.) 실패 시 nil.
    static func parseKSTDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        if let date = parseISO8601(raw) { return date }   // 오프셋 있으면 표준 파서로
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        for format in [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd"
        ] {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) { return date }
        }
        return nil
    }
}
