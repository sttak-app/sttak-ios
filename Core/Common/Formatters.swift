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
}
