import SwiftUI

// MARK: - AppFont — 역할별 타입 스케일
//
// 값 출처: docs/design_handoff/README.md(Typography 타입 스케일).
// 폰트 패밀리: 본문/한글 = Pretendard, 숫자/지표 = Space Grotesk.
//
// ⚠ 커스텀 폰트(Pretendard / Space Grotesk)는 아직 레포에 번들되지 않았다.
//   폰트 파일이 없으면 Font.custom 은 조용히 시스템 폰트로 폴백한다(크기·굵기는 유지).
//   실제 렌더하려면 Resources/Fonts/README.md 의 3단계(번들 / Info.plist UIAppFonts /
//   project.yml 리소스)를 완료해야 한다. 폰트 추가 후엔 이 파일 수정 없이 자동 적용된다.
enum AppFont {

    // MARK: 패밀리 리졸버 (커스텀 폰트의 단일 전환 지점)

    /// 본문/한글 — Pretendard. 미번들 시 시스템 폰트로 폴백.
    static func pretendard(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        Font.custom(pretendardName(weight), size: size).weight(weight)
    }

    /// 숫자/지표 — Space Grotesk. 미번들 시 시스템 폰트로 폴백.
    static func spaceGrotesk(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        Font.custom(spaceGroteskName(weight), size: size).weight(weight)
    }

    private static func pretendardName(_ w: Font.Weight) -> String {
        switch w {
        case .bold, .heavy, .black: return "Pretendard-Bold"
        case .semibold: return "Pretendard-SemiBold"
        case .medium: return "Pretendard-Medium"
        default: return "Pretendard-Regular"
        }
    }

    private static func spaceGroteskName(_ w: Font.Weight) -> String {
        switch w {
        case .bold, .heavy, .black: return "SpaceGrotesk-Bold"
        case .semibold: return "SpaceGrotesk-SemiBold"
        case .medium: return "SpaceGrotesk-Medium"
        default: return "SpaceGrotesk-Regular"
        }
    }

    // MARK: 텍스트 역할 토큰 (Pretendard)

    static let splashWordmark = pretendard(40, .bold)  // 스플래시 로고 워드마크
    static let loginHeadline = pretendard(27, .bold)   // 로그인 헤드라인
    static let screenTitle = pretendard(24, .bold)     // 화면 타이틀(퀴즈/랭킹 등)
    static let homeGreeting = pretendard(22, .bold)    // 홈 그리팅·종목명 헤더
    static let resultTitle = pretendard(21, .bold)     // 결과 타이틀
    static let focusCardTitle = pretendard(19, .bold)  // 포커스 카드 종목명 / 배너
    static let quizQuestion = pretendard(18.5, .bold)  // 퀴즈 질문
    static let sectionHeader = pretendard(16, .bold)   // 섹션 헤더 / CTA 라벨
    static let ctaLabel = pretendard(16, .bold)
    static let listItem = pretendard(15, .semibold)    // 리스트 항목명 / 본문 강조
    static let newsTitle = pretendard(14.5, .semibold) // 뉴스 제목 / 옵션 라벨
    static let body = pretendard(14, .medium)          // 본문 (13.5~14/500~600 중 14/500)
    static let bodyStrong = pretendard(13.5, .semibold)// 본문 강조 (쉬운풀이 등)
    static let metaCaption = pretendard(12.5, .semibold) // 메타·캡션
    static let badge = pretendard(11.5, .bold)         // 배지
    static let microCaption = pretendard(11, .semibold) // 마이크로 캡션

    // MARK: 숫자 역할 토큰 (Space Grotesk)
    //
    // 핸드오프 "숫자 강조: 25~38/700"(자산·자본금·카운트다운). 컨텍스트별 크기는
    // number(_:_:) 로 직접 지정. 대표 토큰 2종만 제공.
    static let numberHero = spaceGrotesk(34, .bold)    // 총자산·자본금 등 큰 숫자
    static let numberLarge = spaceGrotesk(25, .bold)   // 카운트다운·순위 값 등

    /// 임의 크기 숫자(가격·등락률 등). 기본 굵기 .bold.
    static func number(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        spaceGrotesk(size, weight)
    }
}
