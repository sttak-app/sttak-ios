import SwiftUI

// MARK: - AppSpacing — 간격 스케일
//
// 값 출처: docs/design_handoff README + 전 화면 CSS 실측(빈도 집계).
// 화면에서 매직 넘버 대신 이 토큰을 사용한다.
enum AppSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24

    // 의미 기반 (핸드오프 명시 범위 내 대표값)
    static let screenHorizontal: CGFloat = 22 // 화면 가로 패딩 22~24
    static let cardPadding: CGFloat = 18       // 카드 내부 16~22 (실측 최빈값 18)
    static let sectionGap: CGFloat = 20        // 섹션 간 18~24
    static let cardGap: CGFloat = 8            // 카드 간 8~10
}

// MARK: - AppRadius — 모서리 반경 스케일
//
// 값 출처: 전 화면 border-radius 실측. (pill=999, 카드=16/18, 배너=20, 칩=10/12, 행=14)
enum AppRadius {
    static let chipSmall: CGFloat = 10  // 칩/세그먼트 (작은)
    static let chip: CGFloat = 12       // 칩/세그먼트
    static let row: CGFloat = 14        // 리스트 행/옵션
    static let card: CGFloat = 16       // 카드 (최빈)
    static let cardLarge: CGFloat = 18  // 카드 변형
    static let banner: CGFloat = 20     // 큰 카드/배너
    static let screen: CGFloat = 45     // iOS 화면 프레임(참고)
    static let pill: CGFloat = 999      // 배지/필
}

// MARK: - AppShadow — elevation 토큰 (1단계만, 아주 절제)
//
// 값 출처: 핸드오프 Shadow 토큰. CSS box-shadow → SwiftUI .shadow 근사.
// rgba(40,36,28,…) = #28241C.
struct ShadowToken: Sendable {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

enum AppShadow {
    /// 카드: 0 1px 3px rgba(40,36,28,0.06)
    static let card = ShadowToken(color: Color(rgb: 0x28241C, opacity: 0.06), radius: 3, x: 0, y: 1)
    /// 칩: 0 1px 2px rgba(40,36,28,0.05)
    static let chip = ShadowToken(color: Color(rgb: 0x28241C, opacity: 0.05), radius: 2, x: 0, y: 1)
    /// 틸 CTA(프라이머리 버튼만): 0 6px 18px rgba(15,163,154,0.30)
    static let accentCTA = ShadowToken(color: Color(rgb: 0x0FA39A, opacity: 0.30), radius: 18, x: 0, y: 6)
}

extension View {
    /// 디자인 토큰 그림자를 적용한다.
    func appShadow(_ token: ShadowToken) -> some View {
        shadow(color: token.color, radius: token.radius, x: token.x, y: token.y)
    }
}
