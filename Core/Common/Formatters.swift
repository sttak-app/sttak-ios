import Foundation

/// 표현 계층 숫자 포맷터(가격·등락률 등). 도메인은 값만, 포맷은 여기서.
enum Formatters {
    /// 천 단위 구분 정수 문자열. 예: 71200 → "71,200".
    static func grouped(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// 부호 있는 퍼센트. 예: 1.78 → "+1.78%", -0.81 → "-0.81%".
    static func signedPercent(_ value: Double, fractionDigits: Int = 2) -> String {
        let sign = value >= 0 ? "+" : ""
        return sign + String(format: "%.\(fractionDigits)f", value) + "%"
    }

    /// 보유 자산(만원 단위). 예: 10,000,000 → "1,000만원".
    static func assetManwon(_ amount: Int) -> String {
        grouped(amount / 10_000) + "만원"
    }

    /// 한국어 날짜. 예: "6월 18일".
    static func koreanDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"
        return formatter.string(from: date)
    }

    /// 카운트다운 HH:MM:SS (target까지 남은 시간, 음수는 00:00:00).
    static func countdown(from now: Date, to target: Date) -> String {
        let seconds = max(0, Int(target.timeIntervalSince(now)))
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }

    /// 상대 시각. 예: "방금", "32분 전", "3시간 전".
    static func relativeTime(_ date: Date, reference: Date) -> String {
        let seconds = max(0, reference.timeIntervalSince(date))
        let minutes = Int(seconds / 60)
        if minutes < 1 { return "방금" }
        if minutes < 60 { return "\(minutes)분 전" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)시간 전" }
        return "\(hours / 24)일 전"
    }
}
