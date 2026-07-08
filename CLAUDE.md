# CLAUDE.md — sttak iOS

> AI 협업·작업 규칙의 단일 기준. 상세 설계는 `docs/ARCHITECTURE.md`, 디자인 의도는
> `docs/design_handoff/README.md`를 따른다. 충돌 시 우선순위: **이 파일 > ARCHITECTURE.md > 핸드오프**.

## 1. 앱 목적
주식 초보자를 위한 **"투자 학습 + 모의투자"** iOS 앱.
- **관심종목 브리핑**: 뉴스/공시를 호재·중립·악재로 정리 + 쉬운 한국어 풀이.
- **차트학습 + 모의투자**: 캔들차트·지표 6종·과거 신호 → 근거 입력 매매 → AI 회고.
- **퀴즈·랭킹**: 6시간마다 퀴즈 → 정답 시 모의 자본금 적립 → 랭킹.
- 톤: 토스/케이뱅크식 신뢰감 + **따뜻한 종이톤(#F7F4EE)**. AI는 전면에 내세우지 않는다.

## 2. 빌드 타깃
| 항목 | 값 |
|---|---|
| 최소 OS | **iOS 17.0** |
| Swift | **Swift 6 언어 모드**, strict concurrency `complete` |
| Xcode | **26.x** (`.xcode-version` 고정) — 설계 문서의 "16" 기준은 실제 설치본 26.5로 대체 |
| UI | **SwiftUI 단독** + async/await (Combine 미사용) |
| 차트 | **Swift Charts 우선**, `ChartRenderer` protocol로 분리 |

## 3. 아키텍처 (확정)
**MVVM + 얇은 UseCase + Repository.** 풀 Clean/DDD/멀티모듈/TCA는 채택 안 함(과설계).
```
View(SwiftUI) → ViewModel(@Observable, @MainActor) → UseCase(선택적) → Repository(protocol)
                                                                          ├ RemoteDataSource(API)
                                                                          └ LocalDataSource(캐시)
```
- **UseCase는 선택적**: 순수 도메인 로직/다중 소스 조합만 둔다. 단순 위임은 ViewModel이 Repository 직접 호출.
- **DI**: 수동 생성자 주입 + 단일 컴포지션 루트 `AppContainer`. SwiftUI Environment로 전달.
  전역 가변 싱글톤·Service Locator·DI 프레임워크 금지.
- **지표 계산(MA/RSI/볼린저)·신호 탐지는 온디바이스**(순수 수식, 테스트 1순위).

## 4. 폴더 규칙
```
App/        @main, RootView, AppContainer(DI 컴포지션 루트)
Core/       DesignSystem(토큰·공용 컴포넌트) · Networking · Persistence · Common
Domain/     Entities · ValueObjects · Indicators(지표/신호) · UseCases  (Foundation만 의존)
Data/       Repositories(구현) · Remote(DTO·매핑) · Mock(서버 없이 구동)
Features/   화면 단위(View+ViewModel): Onboarding/Home/ChartLearning/Quiz/Ranking/My/Chat
Resources/  폰트·Assets·Localizable
Tests/      DomainTests · DataTests · FeatureTests
```
- 의존 방향: `Features → Domain ← Data`. Domain은 UIKit/SwiftUI/서버를 **모른다**.
- 새 화면은 `Features/<Name>/`에 `XxxView.swift` + `XxxViewModel.swift`로 추가.
- 폴더를 새로 쓸 때 **`project.yml`의 sources에 등록** 후 `xcodegen generate` (§7).

## 5. 백엔드 / 데이터 원칙
- 백엔드는 **외부 팀의 Spring(BFF)**. 앱은 **이 백엔드만** 호출한다. BaaS 미사용.
- LLM(**Claude API**: 분류·퀴즈=Haiku / 챗봇·회고=Sonnet)·시세(**KIS Developers**)·뉴스 **키는 전부 서버**.
  **클라이언트에 키·시크릿을 절대 박지 않는다.**
- 앱↔서버 인터페이스는 **OpenAPI 계약** 기준. 인증: 소셜(카카오·구글·Apple) → 서버 검증 →
  자체 **JWT(액세스+리프레시)** → **Keychain** 저장(UserDefaults 금지).
- 데이터 SSOT: 포트폴리오·거래·퀴즈는 **서버가 원본, 로컬은 캐시**. (Repository가 흡수)
- **지금은 Mock-first**: 모든 서버 기능은 Repository protocol 뒤에 두고 `Mock*Repository`로 개발한다.
  **Live 백엔드 연동은 OpenAPI 스펙 확정 시까지 보류**(ARCHITECTURE §12 커밋 9 Live 와이어링·22).

## 6. 네이밍 / 코딩 컨벤션
- 타입 `UpperCamelCase`, 멤버·변수 `lowerCamelCase`. 약어는 한 단어 취급(`apiClient`, `jwtToken`).
- 파일명 = 주 타입명(`HomeView.swift`). View는 `~View`, 뷰모델은 `~ViewModel`, 프로토콜은
  역할 명사(`NewsRepository`)·구현은 접두(`LiveNewsRepository` / `MockNewsRepository`).
- ViewModel은 `@Observable` + `@MainActor`. 비동기는 `async/await`. 콜백/Combine 지양.
- 강제 언래핑(`!`)·`fatalError` 프로덕션 경로 금지(테스트/프리뷰 예외). 의미 색은 토큰으로만
  (호재=빨강 `#E14B43`/악재=파랑 `#3A6DE8`/중립=회색, 틸 `#0FA39A`는 등락에 쓰지 않음).
- 들여쓰기 4 spaces. 한 파일은 한 가지 책임. 주석은 "왜"를 적고 한국어 OK.

## 7. 프로젝트 관리 (XcodeGen)
- **`project.yml`이 단일 진실원**. `.xcodeproj`는 생성물 — Xcode에서 직접 타깃/파일 구조를 바꾸지 말 것.
- 파일/폴더 추가·이동 후: `xcodegen generate` 실행 → 재생성된 `.xcodeproj`로 빌드.
- 설치: `brew install xcodegen`. Xcode 선택: `sudo xcode-select -s /Applications/Xcode.app`.

## 8. 작업 규칙 (반드시 준수)
1. **한 번에 한 기능/한 커밋 단위**로 진행한다(ARCHITECTURE §12 순서).
2. **모르거나 가정이 필요하면 추측하지 말고 질문**한다. 특히 서버 계약·디자인 스펙이 모호하면 멈춘다.
3. 작업이 끝나면 **빌드/실행 방법 + 변경한 파일 목록**을 설명하고 멈춘다.
4. **커밋·푸시는 사용자 승인("커밋해줘") 후에만** 한다. 임의로 git commit 금지.
5. 시크릿(키·토큰·`.p8`·프로비저닝)을 코드/커밋에 넣지 않는다.
6. 디자인은 `docs/design_handoff` 토큰·의도를 따른다. AI를 강조하지 않고, 판단은 단정적이지 않게.

## 9. 테스트
순수 로직은 빠짐없이, UI는 얇게. 우선순위: 지표/신호 → 도메인 UseCase(매매·퀴즈 채점) →
Data 디코딩/매핑 → ViewModel 상태 전이(Mock repo). 스냅샷/UI는 MVP에서 최소.
