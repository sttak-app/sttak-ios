# sttak iOS — 아키텍처 설계안 (승인됨)

> 이 문서는 구현 기준 설계서입니다. 초기 제안의 "확인 필요한 질문"은 사용자가
> 모두 결정했고, 그 결과를 본문과 **부록 B(확정 결정 로그)** 에 반영했습니다.
> 디자인 핸드오프(`docs/design_handoff/README.md`)·데이터 모듈(`sttak-data.js`)·
> 프로토타입 HTML이 제품 근거입니다.
>
> 작성 기준: 1인 개발 MVP. 모든 결정은 **"가장 단순하면서 확장 가능한 안"** 을 따르고,
> 더 무거운/가벼운 대안을 함께 적습니다.
>
> **개발 모드: Mock-first.** §12 커밋 순서를 따르되, **Live 백엔드 연동(커밋 9·22)은
> 외부 팀의 Spring BFF OpenAPI 스펙이 확정될 때까지 보류**합니다. 그때까지 전 기능을
> `Mock*Repository`로 완주합니다.

---

## 0. 타깃 / 언어 / 빌드 기준 (추천)

| 항목 | 추천 | 근거 / 대안 |
|---|---|---|
| 최소 OS | **iOS 17** | 요청대로 17 유지. `@Observable`(Observation), `SwiftData`, `NavigationStack` 등 현대 SwiftUI API가 모두 17부터 안정적. 18로 올리면 커버리지만 줄고 얻는 건 적음. 대안: 차트 라이브러리/SwiftData 신기능을 강하게 쓰고 싶으면 18. |
| Swift | **Swift 6 언어 모드 + strict concurrency `complete`** | 요청대로. 단 1인 MVP에서 처음부터 `complete`가 부담되면 **초기엔 Swift 5 모드 + `targeted` 동시성 경고로 시작 → 안정화 후 6 모드 승격**도 합리적. 신규 코드라 6 모드로 바로 시작하는 걸 추천(나중 마이그레이션 비용 회피). |
| Xcode | **Xcode 26.x (설치 버전 26.5)** | 초기 기준값이던 "16"은 설치본으로 대체. 팀/CI 재현성을 위해 `.xcode-version`(=`26.5`)로 고정. |
| UI | **SwiftUI 단독** | 핸드오프가 "iOS 네이티브 느낌"을 핵심으로 명시. UIKit은 차트 제스처 등 특수 영역에서만 `UIViewRepresentable`로 부분 차용. |
| 차트 | **Swift Charts 우선, 렌더러는 protocol로 분리** | (확정 E10) `ChartRenderer` 인터페이스 뒤에 Swift Charts 구현을 둠. 핀치줌·구간 색칠 등 한계에 부딪히면 `Canvas`/`UIViewRepresentable` 구현으로 **교체만** 하면 됨(View·도메인 불변). |
| 동시성 | **async/await + Actor**, Combine 미사용(또는 최소) | 스트리밍 챗봇/실시간 시세는 `AsyncStream`/`AsyncThrowingStream`으로 충분. Combine 도입은 과설계. |

---

## 1. 핵심 도메인 (Entity / Value Object / UseCase 후보)

도메인은 프로토타입의 `localStorage` 공유 키와 `sttak-data.js` 구조에서 직접 도출했습니다.

### 1.1 Entity (식별자를 갖고 수명주기가 있는 것)

- **User** — 인증 수단(kakao/google/**apple**), 닉네임, 관심종목 목록(최대 5).
- **Stock** — `code`(식별자) + **`market`/`exchange`**(KOSPI/KOSDAQ, 추후 NYSE/NASDAQ 등), `name`, `sector`, **`currency`**. 현재가/등락률은 시간에 따라 변함 → 별도 `Quote`로 분리. (확정 D7: 해외 확장 대비해 `market`/`currency`를 지금부터 모델에 포함, 기능은 MVP 이후.)
- **Portfolio** — `cash`(초기 10,000,000원), 보유 종목들, 평가금액/손익 파생.
- **Trade** — 한 건의 매수/매도 기록(타입·종목·수량·체결가·근거·시각·연결된 회고).
- **Retrospective** — 한 매도 건에 종속된 AI 회고(직후 회고 + 한 달 후 후속 회고).
- **QuizSet** — 6시간 주기로 생성되는 3문제 세트(응시 시각·정답수·적립 자본금).
- **ChatSession** — 뉴스/구간/자유 질문 컨텍스트의 챗봇 대화.
- **RankingSnapshot** — 시점별 랭킹 목록(서버 산출, **보유 자산 단일 리더보드**).

### 1.2 Value Object (식별자 없는 불변 값)

- **Sentiment** — `호재 / 중립 / 악재` (enum). 색 매핑(빨강/회색/파랑)은 표현 계층에서.
- **Money** — `amount`(최소단위 정수) + **`currency`**(KRW 기본, 추후 USD 등) 래퍼. "게임 코인 아님" 원칙 → 통화별 포맷터. MVP는 KRW만 노출하되 타입은 통화 일반화(확정 D7).
- **NewsItem** — `sentiment, title, easy(한 줄), summary(100자), why[], reason, terms[], source, time, originalURL, lead`. (식별자가 없으면 `id` 부여해 Entity화 가능 — 서버 도입 시 결정)
- **Term** — `{ term, def }` 용어 풀이.
- **Quote** — `price, change%, sparkline[]` 시세 스냅샷.
- **Candle** — `date, open, high, low, close, volume`.
- **IndicatorKind** — `정보 / 지지저항 / 이동평균 / RSI / 거래량 / 볼린저밴드`.
- **ChartSignal** — `kind(골든크로스/데드크로스/RSI과열/과매도/볼린저 상·하단 터치), index, 설명문, 이후 N일 방향`.
- **QuizQuestion** — `question, options[4], answerIndex, explanation, category`.
- **TradeRationale** — 근거 텍스트(≤140자) + 빠른선택 프리셋.
- *(제거됨: League — 제품 결정으로 등급/포인트 미사용. 부록 B 참고.)*

### 1.3 UseCase 후보 (한 줄로 표현되는 동작 단위)

> 1인 MVP에서는 **모든 동작에 UseCase를 강제하지 않습니다.** 아래 중
> ★ 표시(순수 도메인 로직/여러 소스 조합)만 UseCase로 두고, 단순 위임은
> ViewModel이 Repository를 직접 호출합니다. (§5의 "UseCase는 선택적" 참고)

| UseCase | 실행 위치 | 비고 |
|---|---|---|
| `LoadDailyBriefing` ★ | 클라(조합) | 관심종목 시세 + 분류된 뉴스 모아 홈 무드 구성 |
| `ClassifyNewsSentiment` | **서버(LLM)** | 호재/중립/악재 + 쉬운풀이·summary·why·reason·terms |
| `AskChatbot` (stream) | **서버(LLM)** | 뉴스/구간/자유 질문, 스트리밍 응답 |
| `ExecuteTrade` ★ | 클라(도메인) | 근거 필수 검증 → cash/보유 갱신 → 기록 저장 |
| `ComputeIndicator` (MA/RSI/볼린저) ★ | **온디바이스** | 순수 수식. 키 불필요 → 테스트 1순위 |
| `DetectChartSignals` ★ | **온디바이스** | 골든/데드크로스·RSI 임계·밴드 터치 탐지 |
| `GenerateSellRetrospective` | **서버(LLM)** | 매도 직후 회고(잘한 점/함께 볼 점) |
| `GenerateFollowUpRetro` | **서버(LLM)** | 한 달 뒤 실제가 비교 후속 회고 |
| `GenerateQuizSet` | **서버(LLM, 배치)** | 6시간 주기 생성 |
| `ScoreQuizAndAwardCapital` ★ | 클라(도메인) | 정답수 → +50만/문항(자본금만), 6h 쿨다운 |
| `ComputeRanking` | **서버** | 보유 자산 랭킹·변동 |

→ "★ = 온디바이스 순수 로직"은 키가 필요 없고 단위 테스트가 쉬움. "서버(LLM)"는
전부 §3에서 다루는 **백엔드 경유 + protocol 추상화** 대상입니다.

---

## 2. 디렉토리 구조 + 각 디렉토리 책임

MVP는 **단일 앱 타깃 + 폴더(그룹) 기반 Feature 구획**으로 시작합니다.
(모듈 분리는 §4 참고 — 지금 나누면 과설계.)

```
sttak-ios/
├─ project.yml                 # XcodeGen 선언 (§3) — .pbxproj는 생성물
├─ .xcode-version              # Xcode 버전 고정
├─ App/
│  ├─ sttakApp.swift           # @main, 의존성 컴포지션 루트(AppContainer 주입)
│  ├─ RootView.swift           # 스플래시→로그인→온보딩→탭 라우팅
│  └─ AppContainer.swift       # DI 컴포지션 루트 (§6)
├─ Core/                       # 기능 공통 토대 (UI 아님)
│  ├─ DesignSystem/            # 디자인 토큰(색/타이포/spacing/radius), 공용 컴포넌트
│  │  ├─ Color+Tokens.swift    #   #F7F4EE, 틸, 호재빨강/악재파랑 등 핸드오프 토큰
│  │  ├─ Typography.swift      #   Pretendard / Space Grotesk(숫자) 스케일
│  │  └─ Components/           #   Badge, Segment, Sheet, Pill, ReticleLogo(SVG→Shape)
│  ├─ Networking/              # API 클라이언트, 엔드포인트, 디코딩
│  ├─ Persistence/             # 로컬 저장(포트폴리오/거래/설정) — §5 DataSource
│  ├─ Concurrency/             # AsyncStream 헬퍼 등
│  └─ Common/                  # Money 포맷터, Date 유틸, Result 확장
├─ Domain/                     # 순수 Swift, 프레임워크 의존 최소 (Foundation만)
│  ├─ Entities/                # User, Stock, Portfolio, Trade, QuizSet ...
│  ├─ ValueObjects/            # Sentiment, Money, Candle, IndicatorKind ...
│  ├─ Indicators/              # MA/RSI/Bollinger 계산 + 신호 탐지 (테스트 핵심)
│  └─ UseCases/                # ★ 표시한 도메인 로직만
├─ Data/                       # Domain의 Repository 프로토콜 "구현"
│  ├─ Repositories/            # 실제 구현 (서버/로컬 조합)
│  ├─ Remote/                  # DTO + 매핑 (서버 응답 → 도메인)
│  └─ Mock/                    # ★ Mock 구현 — 서버 없이 전체 앱 구동(sttak-data 이식)
├─ Features/                   # 화면 단위 (View + ViewModel)
│  ├─ Onboarding/              # 스플래시·로그인·관심종목 선택
│  ├─ Home/                    # 3초 브리핑·포커스 카드·뉴스 상세 시트
│  ├─ ChartLearning/           # 캔들차트·지표·과거신호·모의매매·회고
│  ├─ Quiz/                    # 퀴즈·결과·쿨다운
│  ├─ Ranking/                 # 랭킹
│  ├─ My/                      # 마이페이지(자산·기록·회고·랭킹 진입)
│  └─ Chat/                    # 공용 챗봇 시트
├─ Resources/                  # 폰트, Assets, Localizable
└─ Tests/
   ├─ DomainTests/             # 지표/신호/포트폴리오/퀴즈 채점
   ├─ DataTests/               # DTO 디코딩, 매핑, Mock 일관성
   └─ FeatureTests/            # ViewModel(+Mock repo) 상태 전이
```

**책임 한 줄 요약**
- `Domain`: 앱이 무엇인지(규칙). 프레임워크/서버를 모름 → 가장 테스트하기 쉬움.
- `Data`: 규칙을 외부(서버/로컬)와 연결. Repository 프로토콜은 Domain에, 구현은 여기.
- `Features`: 화면. ViewModel이 UseCase/Repository를 호출하고 View는 상태만 그림.
- `Core`: 모든 Feature가 쓰는 토대(디자인 시스템·네트워킹·저장).

---

## 3. Xcode 프로젝트 관리 방식 (비교 + 추천)

손으로 `.pbxproj`를 편집하면 충돌·깨짐이 잦고, **AI와 협업 시 파일 추가/이동이 빈번**하므로
선언적 방식이 필수입니다.

| 방식 | 장점 | 단점 | AI 협업 적합도 |
|---|---|---|---|
| `.xcodeproj` 직접 | 추가 도구 0 | `.pbxproj` 머지 충돌·수작업 편집 위험 큼 | ✕ 낮음 |
| **XcodeGen** | `project.yml` 한 파일로 선언, 학습 쉬움, 폴더=그룹 자동, git diff 깔끔 | 모듈 그래프·캐시는 약함 | ◎ 높음 |
| Tuist | 모듈/그래프/캐시/스캐폴딩 강력, 대규모에 강함 | 학습곡선·Swift manifest·도구 무게 | ○ (지금은 과함) |
| SwiftPM 단독 | 표준·의존성 관리 일급 | **앱(.app) 타깃을 SPM만으로 못 만듦** → 결국 얇은 xcodeproj 필요 | △ (단독 불가) |

**추천: XcodeGen으로 앱 프로젝트를 선언 + 의존성은 SwiftPM.**
- 근거: 1인 MVP에서 `project.yml`은 사람이 읽고 AI가 안전하게 수정하기 가장 쉬운 선언 포맷이고,
  파일을 추가해도 `xcodegen generate`로 `.pbxproj`가 재생성돼 머지 충돌이 사라집니다.
- 외부 라이브러리는 SwiftPM으로(예: Pretendard는 직접 번들, 차트는 자체 구현 권장 §10).
- **`.xcodeproj`/`.pbxproj`는 빌드 산출물 취급 → `.gitignore`로 추적 제외(채택).** `project.yml`만 커밋하고
  클론 후 `xcodegen generate`로 생성. 규칙: "직접 수정 금지, `project.yml`만 수정". (AI가 파일을 자주
  추가해 재생성이 잦으므로 생성물을 커밋하면 diff 노이즈가 큼 → 제외가 더 깔끔.)
- **확장 경로**: 모듈이 5개+로 커지고 빌드시간/경계가 문제되면 그때 **Tuist로 승격**. 지금 Tuist는
  "혼자 만드는 MVP"에 비해 명백히 과설계.
- 더 단순한 대안: 정말 최소로 가려면 `.xcodeproj`를 한 번 만들고 폴더 그룹만 쓰되 파일 추가를
  최소화 — 그러나 AI가 파일을 자주 추가하는 이 워크플로엔 XcodeGen이 분명히 낫습니다.

---

## 4. Feature 단위 vs Domain 단위 모듈화 (비교 + 이 앱 추천)

- **Feature 단위 모듈**(Home, Quiz...): 화면 병렬 개발·소유권 명확. 단, 도메인이 여러 피처에 걸치면 중복/순환.
- **Domain(레이어) 단위 모듈**(Domain/Data/UI): 의존 방향이 단순(UI→Domain←Data). 1인에 직관적.

**이 앱 추천: 지금은 "모듈 없이 폴더로만" Feature 구획 + 레이어 폴더(§2).**
- 근거: 모듈(별도 SPM 타깃) 분리는 **빌드 경계·접근제어·테스트 격리**가 필요할 때 값을 합니다.
  1인 MVP·화면 6개 규모에서는 그 이득보다 보일러플레이트(타깃·Package.swift·public 노출)가 큽니다.
- **확장 경로(권장 순서)**: 경계가 안정되면 ① `DesignSystem` → ② `Domain`(+Indicators) →
  ③ `Data`(Mock 포함) 순으로 **로컬 SwiftPM 패키지**로 추출. 이 세 개가 가장 재사용·테스트 가치가 큼.
  Feature별 모듈화는 가장 마지막(혹은 안 해도 됨).
- 더 무거운 대안(지금 비추천): 처음부터 Feature×Layer 매트릭스 멀티모듈 → 1인에 명백한 과설계.

---

## 5. 추천 아키텍처 + 각 레이어 역할

**추천: MVVM + (얇은) UseCase + Repository.** Clean Architecture의 *의존성 방향*만 빌려오고,
풀 DDD/멀티모듈은 채택하지 않습니다.

```
View(SwiftUI)  ─▶  ViewModel(@Observable)  ─▶  UseCase(선택적)  ─▶  Repository(protocol)
                                                                         │
                                                       ┌─────────────────┴─────────────────┐
                                              RemoteDataSource(API)              LocalDataSource(저장)
                                                       │
                                              (Mock 구현으로 교체 가능)
```

- **View**: 상태를 그리고 사용자 입력을 ViewModel로 전달. 로직 없음. 디자인 토큰만 소비.
- **ViewModel** (`@Observable`, `@MainActor`): 화면 상태(loading/loaded/error) 보유,
  UseCase/Repository 호출, 도메인 모델 → 표시 모델 변환. 프로토타입의 화면별 `state`(§State Management)
  가 거의 1:1로 여기 매핑됩니다(예: 차트학습의 `period/zoom/indicator/sheet/retro`).
- **UseCase (선택적)**: §1.3에서 ★ 표시한 **순수 도메인 로직·다중 소스 조합**만.
  단순 "Repository 한 번 호출"은 UseCase 없이 ViewModel→Repository 직접 호출.
  → *근거*: 1인 MVP에서 동작마다 UseCase 클래스를 만들면 파일만 폭증. 가치 있는 곳만 둠.
- **Repository (protocol)**: Domain이 선언, Data가 구현. **서버 의존을 가두는 경계** → §3의 LLM/시세
  기능이 전부 여기 protocol로 추상화됩니다. 예: `NewsRepository`, `MarketDataRepository`,
  `ChatRepository`, `RetrospectiveRepository`, `QuizRepository`, `PortfolioRepository`, `AuthRepository`,
  `RankingRepository`.
- **DataSource**: Remote(API 호출+DTO 디코딩), Local(캐시·설정 저장).
  Repository가 둘을 조합.
- **서버 = 원본(SSOT), 로컬 = 캐시 (확정 C5)**: 포트폴리오·거래·퀴즈 진행은 **Live에서 서버가 원본**이고
  로컬은 캐시/오프라인 표시용입니다. 매수/매도·퀴즈 적립 같은 **쓰기는 서버에 반영**하고 응답으로 갱신.
  → 이 정책을 ViewModel이 모르게 **Repository 안에 흡수**합니다(예: `PortfolioRepository.execute(trade)`가
  Live에선 서버 POST, Mock에선 로컬 갱신). Mock 단계는 전부 로컬 저장으로 완주.

### Mock-first 개발 전략 (요청 핵심)
- 각 Repository protocol에 **두 구현**: `LiveXxxRepository`(서버), `MockXxxRepository`(`sttak-data` 이식).
- 앱 시작 시 `AppContainer`가 환경(`#if DEBUG`/런치 인자/Settings)에 따라 주입 구현 선택.
- 효과: **서버가 없어도 전체 플로우(홈·뉴스시트·차트·매매·회고·퀴즈·랭킹)를 Mock으로 완주** 가능.
  스트리밍 챗봇/회고도 Mock에서 `AsyncStream`으로 한 글자씩 흘려 동일 UX 재현.

---

## 6. DI 구성안 (DI Container vs Service Locator)

| 방식 | 장점 | 단점 |
|---|---|---|
| **수동 생성자 주입 + Composition Root** | 의존성 명시적, 컴파일 타임 안전, 테스트 시 Mock 주입 쉬움, 무프레임워크 | 와이어링 코드 약간 |
| Service Locator (전역 registry) | 호출부 간결 | **의존성 은닉**(런타임 실패·테스트 격리 어려움) → 안티패턴 취급 |
| DI 프레임워크(Swinject 등) | 자동 해결 | 1인 규모엔 무게·런타임 오류 위험 |

**추천: 수동 생성자 주입 + 단일 컴포지션 루트(`AppContainer`).**
- `AppContainer`가 모든 Repository/UseCase를 한 곳에서 조립하고, SwiftUI **Environment**로 ViewModel
  팩토리를 하위 뷰에 내려보냅니다(전역 가변 싱글톤 금지).
- 근거: 화면 6개 규모에서 프레임워크/서비스 로케이터는 얻는 것보다 잃는 게(가독성·테스트성) 큼.
- 더 단순한 대안: 의존성이 정말 적으면 `@Environment` 키로 Repository 직접 주입.
- 확장 경로: 그래프가 커지면 그때 가벼운 팩토리 패턴/프로퍼티 래퍼 정도만 추가.

---

## 7. 현실적인 테스트 범위

ROI 순으로, 1인이 **유지 가능한 만큼만**:

1. **Domain/Indicators (최우선, 단위테스트)** — MA/RSI/볼린저 수치, 골든·데드크로스/과열·과매도/밴드
   터치 신호 탐지. 입력 캔들 → 기대 신호 인덱스. (키·네트워크 0, 회귀 위험 큼 → 가성비 최고)
2. **Domain/UseCases (단위)** — `ExecuteTrade`(근거 미입력 거부, cash/보유 갱신, 부분매도),
   `ScoreQuizAndAwardCapital`(정답수→자본금, 6h 쿨다운), 손익/평가금액 계산.
3. **Data (단위)** — DTO 디코딩(샘플 JSON), 도메인 매핑, **Mock과 Live의 인터페이스 동일성**.
4. **ViewModel (단위, Mock repo)** — 핵심 상태 전이: loading→loaded→error, 온보딩 5개 상한,
   홈 스와이프 인덱스, 퀴즈 phase(playing→done→cooldown).
5. **UI 테스트 (최소)** — 스모크 1~2개(앱 부팅→탭 전환). 픽셀 검증은 안 함.
6. **스냅샷 테스트** — *MVP에선 보류*(디자인 변동 큼). 안정화 후 디자인시스템 컴포넌트에 한해 도입 고려.

원칙: **순수 로직은 빠짐없이, UI는 얇게.** 커버리지 숫자 목표 대신 "깨지면 아픈 곳"에 집중.

---

## 8. Git 전략

### 브랜치 (README의 기존 전략 존중 + 1인용 간소화)
- 레포에 이미 `main / develop / feature/* / release/* / hotfix/*` 정의가 있음 → **유지**하되,
  1인 MVP 현실상 **`develop`(통합) + `feature/*`** 만 상시 사용하고, `release/*`·`hotfix/*`는
  실제 배포 시점에 도입을 권장(미리 운영하면 오버헤드).
- `main`은 출시 가능 상태만. 평소 작업/PR 머지는 `develop` 대상.

### 커밋 컨벤션 — Conventional Commits
```
<type>(<scope>): <subject>

feat(home): 포커스 종목 카드 스와이프 전환 구현
fix(quiz): 6시간 쿨다운 경계 계산 오류 수정
chore(project): XcodeGen project.yml 초기 설정
docs(arch): 아키텍처 설계안 추가
test(domain): RSI 과열 신호 탐지 테스트 추가
refactor(chart): 지표 계산을 Domain/Indicators로 분리
```
- type: `feat/fix/docs/style/refactor/test/chore/build/ci`.
- scope: 폴더/피처명(`home, chart, quiz, ranking, my, domain, data, design, project`).
- 본문은 한국어 OK. 작은 단위로 자주 커밋.

### Push / PR 정책
- `main`/`develop` 직접 push 금지(가능하면 보호 규칙) → **PR 경유**(기존 PR 템플릿·Jira 연동 활용).
- **시크릿 절대 커밋 금지**: API 키·`.p8`·프로비저닝은 `.gitignore`로 차단(이미 설정됨).
  키는 §3/§9의 백엔드에만. PR 템플릿에 이미 "민감정보 미포함" 체크 항목이 있음 → 그대로 활용.
- 머지 전략: **Squash merge**(1인이라 히스토리 단순화). 머지 후 feature 브랜치 삭제.

---

## 9. GitHub 포함/제외 문서 + 디자인 핸드오프 관리

### 레포에 포함 (권장)
- `README.md`, **`docs/ARCHITECTURE.md`(이 문서)**, 향후 `docs/DECISIONS/`(ADR — 결정 로그).
- `.github/PULL_REQUEST_TEMPLATE.md`(이미 있음), 이슈 템플릿(선택).

### 디자인 핸드오프(`docs/design_handoff/`) — 실무 통례와 추천
- 현재 `.dc.html` 프로토타입 + `support.js`(런타임) + `sttak-data.js`(데이터)가 들어 있음.
- **실무 통례**: 인터랙티브 HTML 시안은 보통 ① Figma/Zeplin 등 **디자인 툴이 원본(SSOT)**,
  레포에는 "스냅샷/핸드오프 참고본"만 둡니다. 시안이 자주 바뀌면 레포가 비대해지므로
  대안으로 **별도 `design` 레포 또는 디자인 툴 링크**만 README에 두기도 합니다.
- **이 프로젝트 추천**:
  - 핸드오프 README(디자인 의도·토큰·화면 스펙)는 **개발의 SSOT급 가치** → 레포 유지.
  - `.dc.html`/`support.js`는 **참고용 동결(frozen reference)** 로 유지하되 빌드/번들에서 제외
    (앱 타깃에 포함 안 함). "프로덕션 무관" 명시됨.
  - `sttak-data.js`의 데이터는 **`Data/Mock`의 Swift fixture로 1차 이식** 후, HTML 데이터는
    참고본으로만. (런타임 의존 금지)
  - `.DS_Store`는 추적 대상에서 제거 권장(`git rm --cached`) — `.gitignore`엔 이미 있음.
- **제외(커밋 금지)**: 빌드 산출물(`DerivedData`, `*.ipa`, `*.dSYM`), 시크릿(`.env`, `*.p8`,
  프로비저닝), 유저 데이터(`xcuserdata`) — `.gitignore`에 이미 반영됨.

---

## 10. AI/서버 의존 기능 — 실행 위치 & 키 보호 (확정)

> **대원칙: 클라이언트에 API 키를 절대 박지 않는다.** LLM·시세·뉴스 키는 모두 **외부 팀의
> Spring 백엔드(BFF)** 에만. 앱은 **이 Spring 백엔드만** 호출하고, 앱↔서버 인터페이스는
> **OpenAPI 계약**이 기준입니다. (확정 A1) BaaS(Firebase/Supabase) 미사용.

| 기능 | 실행 위치 | 키/시크릿 보호 |
|---|---|---|
| 뉴스/공시 → 호재·중립·악재 분류 + 쉬운풀이/요약/용어 | **Spring BFF → Claude API** | LLM 키는 서버에만. 분류/배치는 **Haiku** 티어 |
| 챗봇(뉴스/구간/자유, 스트리밍) | **Spring BFF → Claude API** | 챗봇은 **Sonnet** 티어, 서버에서 스트리밍 프록시 |
| 매도 직후 회고 / 한 달 후 후속 회고 | **Spring BFF → Claude API** | 회고는 **Sonnet** 티어 |
| 퀴즈 6시간 생성 | **Spring BFF → Claude API (배치/캐시)** | **Haiku** 티어, 클라는 생성된 세트를 받기만 |
| 실시간 시세·캔들 차트 데이터 | **Spring BFF 프록시 → KIS Developers** | KIS 앱키/시크릿·토큰은 서버에만 (확정 A3) |
| 지표 계산(MA/RSI/볼린저)·신호 탐지 | **온디바이스** | 키 불필요(순수 수식) → 클라에서 계산 |
| 소셜 로그인(카카오/구글/Apple) | 클라 SDK + 서버 검증 | 클라엔 공개 앱키만, 서버가 소셜 토큰 검증 후 자체 JWT 발급 (확정 B4) |

**LLM 모델 티어링 (확정 A2):** 분류·퀴즈 생성 = **Claude Haiku**, 챗봇·회고 = **Claude Sonnet**.
초기엔 단일 모델로 시작해도 무방. 모델 선택·프롬프트는 전적으로 서버 책임이라 **앱 코드/모델 ID에
영향 없음** — 앱은 결과만 받습니다.

**인증 플로우 (확정 B4):** 카카오/구글/**Apple** 로그인 → 소셜 토큰을 **Spring 서버가 검증** →
서버가 **자체 JWT(액세스 + 리프레시)** 발급 → **Keychain** 저장(UserDefaults 금지). 액세스 만료 시
리프레시로 자동 갱신(401 인터셉터). *Apple 로그인은 소셜 로그인 제공 시 App Store 심사 요건이라 포함.*

**구조: BFF(Backend-for-Frontend).**
- 앱 → **Spring 백엔드**(JWT)만 호출 → 백엔드가 Claude/KIS/뉴스 벤더 호출(키 보유).
- 장점: 키 은닉, 프롬프트/모델 교체가 서버 배포로 끝남(앱 심사 불필요), 비용·rate limit 통제,
  응답 캐싱(뉴스 분류/퀴즈는 사용자 공통이라 캐시 효율 큼).

**후속 회고 전달 (확정 D8):** 한 달 뒤 후속 회고는 **서버 스케줄러가 생성 → APNs 푸시**로 알림.
앱은 푸시 수신 후 마이페이지에서 표시. **Mock 단계는 로컬 타이머/시뮬레이션**으로 재현.

**Mock 추상화:** 위 모든 서버 기능은 §5의 Repository protocol 뒤에 있으므로, 백엔드가 없어도
`Mock*Repository`로 전 기능 개발 가능. **OpenAPI 스펙이 확정되기 전까지 앱은 Mock으로 완성 →
이후 DTO/`Live*Repository`만 끼우면 됨**(커밋 9·22는 그때까지 보류).

---

## 11. MVP에서 먼저 구현할 기능 순서

가치(핵심 차별점) × 의존성(서버 필요도) 균형. **전부 Mock 기반으로 먼저 완주**합니다.

1. **토대**: 프로젝트 생성(XcodeGen) → DesignSystem 토큰/공용 컴포넌트 → AppContainer/라우팅 골격.
2. **온보딩 플로우**: 스플래시 → 로그인(UI, 인증은 Mock) → 관심종목 선택(검색·5개 상한) → 홈 진입.
3. **홈(핵심 차별점 ①)**: 3초 브리핑(무드 바·종목 스트립·포커스 카드 스와이프) → 뉴스 상세 시트
   (쉬운풀이/원문/AI 탭, AI는 Mock 스트리밍). *서버 없이 Mock 데이터로.*
4. **차트학습(핵심 차별점 ②)**: 캔들차트(**Swift Charts 우선, `ChartRenderer` protocol**) → 지표 6종 + **온디바이스 신호 탐지**(테스트 동반)
   → 모의 매수/매도(근거 필수) → 매도 직후 회고(Mock).
5. **퀴즈 + 자본금 연동**: 3문제·채점·해설·결과·6h 쿨다운 → 정답 시 자본금 적립(단일 통화).
6. **마이페이지**: 자산·매매기록·회고기록(아코디언)·랭킹 진입.
7. **랭킹**: 보유 자산 리더보드·내 순위(다른 유저는 **Mock**, 확정 C6).
8. **후속 회고(한 달 뒤)**: Mock 단계는 **로컬 타이머 시뮬레이션**(Live는 서버 스케줄러+APNs, 확정 D8).
9. **백엔드 연동(보류)**: OpenAPI 스펙 확정 후 Repository를 Live로 교체(뉴스 분류·챗봇·회고·퀴즈·시세·인증).

> 가장 먼저 사용자 가치를 증명하는 건 **홈(3초 브리핑) + 차트학습(신호+모의매매)** 이므로
> 이 둘을 MVP의 심장으로 우선합니다. 랭킹/후속회고는 그 다음.

---

## 12. 첫 커밋부터의 커밋 단위 작업 순서

각 줄 ≈ 한 PR/커밋. Conventional Commits 사용.

```
1.  chore(project): XcodeGen project.yml + .xcode-version + 앱 스켈레톤
2.  docs(arch): 아키텍처 설계안 추가              ← (이 문서)
3.  feat(design): 디자인 토큰(Color/Typography/Spacing) + ReticleLogo
4.  feat(design): 공용 컴포넌트(Badge/Segment/Pill/Sheet/PrimaryButton)
5.  feat(domain): 엔티티/VO 정의(Stock·News·Portfolio·Trade·Quiz)
6.  feat(domain): 지표 계산(MA/RSI/Bollinger) + 신호 탐지
7.  test(domain): 지표·신호 단위 테스트
8.  feat(data): Repository 프로토콜 + Mock 구현(sttak-data 이식)
9.  feat(app): AppContainer(DI) + RootView 라우팅 + 스플래시
10. feat(onboarding): 로그인(UI) + 관심종목 선택(검색·5개 상한)
11. feat(home): 3초 브리핑(무드바·스트립·포커스 카드 스와이프)
12. feat(home): 뉴스 상세 시트(쉬운풀이/원문/AI 스트리밍 Mock)
13. feat(chart): 캔들차트 렌더 + 기간/줌/팬
14. feat(chart): 지표 패널 + 과거 신호 시각화
15. feat(chart): 모의 매수/매도(근거 필수) + 매도 직후 회고(Mock)
16. test(domain): ExecuteTrade/포트폴리오 손익 테스트
17. feat(quiz): 3문제·채점·해설·결과·쿨다운 + 자본금 적립
18. test(domain): 퀴즈 채점/쿨다운 테스트
19. feat(my): 마이페이지(자산·매매기록·회고 아코디언·랭킹 진입)
20. feat(ranking): 랭킹(보유 자산·내 순위)
21. feat(chat): 공용 챗봇 시트(Mock 스트리밍)
22. feat(data): Live Repository 연동(OpenAPI 스펙 확정 후 — 보류)
```

> **보류**: 커밋 9(`AppContainer`는 진행하되 Live 와이어링은 Mock으로)·22의 **Live 백엔드 연동은
> Spring 팀 OpenAPI 스펙 확정 시까지 진행하지 않습니다.** 그 전까지 1~21을 Mock으로 완주합니다.
> (커밋 9는 라우팅/DI 골격이므로 Mock 주입 상태로 진행합니다 — Live 연동만 보류.)

---

## 부록 A. 채택하지 않은 것 (의도적 단순화)

- **풀 Clean Architecture / DDD / 멀티모듈** → 1인 MVP에 과설계. 의존성 방향만 차용.
- **DI 프레임워크 / Service Locator** → 수동 주입으로 충분, 더 안전.
- **Combine / TCA(Composable Architecture)** → 보류. TCA는 강력하지만 학습·보일러플레이트가
  1인 MVP 속도를 떨어뜨림. SwiftUI `@Observable` + async/await로 시작. (규모 커지면 재검토)
- **클라 내 LLM 키 / 온디바이스 LLM** → 키 노출·비용·심사 이슈로 백엔드 경유.
- **차트 자체 구현으로 직행** → 채택 안 함. (확정 E10) **Swift Charts로 먼저 구현**하되 `ChartRenderer`
  protocol로 분리해, 인터랙션 한계 시 `Canvas`/`UIViewRepresentable`로 교체. 처음부터 자체 렌더는
  속도를 떨어뜨리므로 표준 우선.

---

## 부록 B. 확정 결정 로그 (사용자 승인)

| # | 주제 | 결정 |
|---|---|---|
| A1 | 백엔드 | 외부 팀 **Spring BFF** 개발 중. BaaS 미사용. 앱은 Spring만 호출, **OpenAPI 계약** 기준. 키 전부 서버. |
| A2 | LLM | **Claude API**. 분류·퀴즈 생성 = **Haiku**, 챗봇·회고 = **Sonnet** 티어링(초기 단일 모델 가능). 모델 선택은 서버 책임 → 앱 무관. |
| A3 | 시세 | **KIS Developers**, Spring 프록시 경유. |
| B4 | 인증 | 카카오·구글·**Apple**. 소셜 토큰 → 서버 검증 → **자체 JWT(액세스+리프레시)** → **Keychain**. |
| C5 | 데이터 SSOT | 포트폴리오·거래·퀴즈는 **서버가 원본, 로컬은 캐시**. Mock=로컬, Live=서버 쓰기. Repository로 흡수. |
| C6 | 랭킹 | 다른 유저는 MVP에선 **Mock**. |
| D7 | 해외 확장 | MVP 이후. 단 `Stock.market`/`exchange`·`Money.currency`를 **지금부터 일반화**. |
| D8 | 후속 회고 | **서버 스케줄러 + APNs 푸시**. Mock 단계는 로컬 시뮬레이션. |
| E9 | 프로젝트 | **XcodeGen 채택**. |
| E10 | 차트 | 렌더러를 **protocol로 분리**, **Swift Charts 우선**(추후 Canvas 교체 가능). |
| F11 | 보상 통화 | **단일 통화 = 모의투자 자본금(원)**. 퀴즈 정답 보상은 자본금만(정답수×50만). **포인트(P) 미사용**. (프로토타입의 별도 포인트 통화는 의도적으로 안 따름) |
| F12 | League | **미사용**(제거). 프로토타입은 포인트 임계로 등급을 매겼으나 포인트가 없어 등급 개념 제외. |
| F13 | 랭킹 | **보유 자산 단일 리더보드**(프로토타입의 포인트 랭킹 모드 제외). |

**작업 규칙(승인):** Mock-first로 §12 순서를 한 번에 하나씩 진행. **Live 연동(커밋 9의 Live 와이어링·22)은
OpenAPI 스펙 확정까지 보류.** 각 커밋 완료 시 **빌드/실행 방법 + 변경 파일**을 설명하고 멈춤.
**사용자가 "커밋해줘" 하기 전엔 git commit 금지.**
