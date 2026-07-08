import SwiftUI

// MARK: - Hex helper (디자인 시스템 내부 전용)

extension Color {
    /// 0xRRGGBB 정수로 sRGB 색을 만든다. 토큰 정의에서만 사용한다.
    init(rgb: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

// MARK: - AppColor — 의미 기반 색 토큰
//
// 모든 화면은 raw hex 대신 이 토큰만 사용한다. (CLAUDE.md §6)
// 값 출처: docs/design_handoff/README.md(Design Tokens) + 실제 프로토타입 코드.
//
// ⚠ 감정색(sentiment) vs 등락색(price)은 다르다:
//   - 뉴스 감정 배지: 실제 코드 `sttak Home.dc.html` 의 sentStyle() 를 정본으로 채택.
//     (README 산문 토큰 주석은 이와 모순돼 폐기 — 호재=빨강/악재=파랑/중립=회색이 맞음)
//   - 등락률 "숫자"·무드바: 한국 증시 관례색(상승=빨강, 하락=파랑).
//   - 틸(accent)은 등락에 절대 쓰지 않는다 — 선택/CTA/학습 강조 전용.
enum AppColor {
    // ── 베이스 / 중립 (종이톤) ──
    static let backgroundApp = Color(rgb: 0xECE9E2)      // 폰 바깥(쇼케이스) 배경
    static let backgroundPrimary = Color(rgb: 0xF7F4EE)  // 앱 화면 베이스 (따뜻한 종이톤)
    static let surface = Color(rgb: 0xFFFFFF)            // 카드/시트 표면
    static let surfaceAlt = Color(rgb: 0xEFEBE2)         // 옅은 카드/칩 배경
    static let surfaceChip = Color(rgb: 0xF0EEE8)        // 중립 배지/칩 배경

    // ── 텍스트 / 잉크 ──
    static let ink = Color(rgb: 0x26241F)        // 본문 텍스트 / 다크 카드 배경
    static let inkSoft = Color(rgb: 0x46443D)    // 보조 본문
    static let textMuted = Color(rgb: 0x8A8478)  // 캡션
    static let textMuted2 = Color(rgb: 0xA39D8E) // 더 옅은 캡션/메타

    // ── 구분선 ──
    static let hairline = Color(rgb: 0xEFEBE2)   // 카드 보더
    static let hairline2 = Color(rgb: 0xF2EEE6)  // 리스트 구분선
    static let divider = Color(rgb: 0xF1ECE3)

    // ── 브랜드 (틸) — 선택/CTA/학습 강조 ──
    static let accent = Color(rgb: 0x0FA39A)         // 브랜드 프라이머리 (CTA, 선택, 로고)
    static let accentDeep = Color(rgb: 0x0E7E77)     // 틸 텍스트(가독성)
    static let accentDeeper = Color(rgb: 0x0E5F58)
    static let accentBright = Color(rgb: 0x37C9BD)   // 다크 카드 위 강조
    static let accentTint = Color(rgb: 0xE7F3F0)     // 틸 연한 배경(선택 행/배지/빠른질문 칩)
    static let accentTintBorder = Color(rgb: 0xBFE3DD)

    // ── 뉴스 감정 (sentiment) — 정본: Home.dc.html sentStyle() ──
    static let sentimentPositive = Color(rgb: 0xD23F33)      // 호재 텍스트
    static let sentimentPositiveTint = Color(rgb: 0xFBECEA)  // 호재 배경
    static let sentimentNegative = Color(rgb: 0x3A6DE8)      // 악재 텍스트
    static let sentimentNegativeTint = Color(rgb: 0xEAF0FB)  // 악재 배경
    static let sentimentNeutral = Color(rgb: 0x8A8478)       // 중립 텍스트
    static let sentimentNeutralTint = Color(rgb: 0xF0EEE8)   // 중립 배경

    // ── 등락 / 무드 (한국 증시 관례색) ──
    static let priceUp = Color(rgb: 0xE14B43)    // 상승/호재 무드 — 빨강
    static let priceDown = Color(rgb: 0x3A6DE8)  // 하락/악재 무드 — 파랑
    static let priceFlat = Color(rgb: 0x8A8478)  // 보합/중립 — 회색

    // ── 다크 자산 카드 위 손익 (핸드오프 #FF8A5C/#7FA9F0 — 부호별, 라이트 배경 priceUp/Down보다 부드러운 톤) ──
    static let assetPnLUp = Color(rgb: 0xFF8A5C)    // 다크 카드 수익(+) — 따뜻한 주황
    static let assetPnLDown = Color(rgb: 0x7FA9F0)  // 다크 카드 손실(−) — 부드러운 파랑

    // ── 순위 변동 (랭킹, 1시간 전 대비 — 가격 등락(빨강/파랑)과 다른 색계) ──
    static let rankUp = Color(rgb: 0x1F8A57)    // 순위 상승 — 초록
    static let rankDown = Color(rgb: 0xC77E7E)  // 순위 하락 — 로즈
    static let rankFlat = Color(rgb: 0xBDB6A7)  // 순위 유지 — 회색

    // ── 외부 브랜드 ──
    static let kakao = Color(rgb: 0xFEE500)
    static let kakaoText = Color(rgb: 0x3C1E1E)

    // ── 퀴즈 정답/오답 ──
    static let correct = Color(rgb: 0x2E9E5B)
    static let correctTint = Color(rgb: 0xE8F5EC)
    static let wrong = Color(rgb: 0xDC5B52)
    static let wrongTint = Color(rgb: 0xFCEDEB)

    /// 파괴적 액션(로그아웃·회원탈퇴). 핸드오프 #B6485F — 절제된 로즈레드.
    static let destructive = Color(rgb: 0xB6485F)

    // ── 차트 지표 팔레트 (참고용 — 최종 적용은 차트 커밋에서) ──
    static let indicatorInfo = Color(rgb: 0x8A8478)        // 정보(시총/PER/PBR)
    static let indicatorSupportResist = Color(rgb: 0x3A6DE8) // 지지·저항
    static let indicatorMA = Color(rgb: 0xE0A33A)          // 이동평균선(앰버, 대표색)
    static let indicatorRSI = Color(rgb: 0x9A7BD0)         // RSI(절제된 보라)

    // ── 랭킹 등급(리그) ──
    static let leagueBronze = Color(rgb: 0xCDA873)
    static let leagueSilver = Color(rgb: 0xAEB4BA)
    static let leagueGold = Color(rgb: 0xE0B43C)
    static let leaguePlatinum = Color(rgb: 0x46C2B6)
    static let leagueDiamond = Color(rgb: 0x6FA0F2)

    // ── 공용 컴포넌트 상태 토큰 (핸드오프 실측, 커밋 4에서 추가) ──
    static let ctaDisabledBackground = Color(rgb: 0xE5E0D6) // PrimaryButton 비활성 배경
    static let ctaDisabledForeground = Color(rgb: 0xB3AC9D) // PrimaryButton 비활성 텍스트
    static let segmentTrack = Color(rgb: 0xEDE9E0)          // Segment 트랙(컨테이너) 배경
    static let segmentUnselectedText = Color(rgb: 0x9A9485) // Segment 미선택 텍스트
    static let controlBorder = Color(rgb: 0xE4DFD4)         // Pill/Segment 비활성 보더
    static let accentTintSoft = Color(rgb: 0xEEF4F2)        // 더 옅은 틸 틴트(빠른질문 Pill)
    static let scrim = Color(rgb: 0x14120E, opacity: 0.42)  // 바텀시트 딤(스크림)
}
