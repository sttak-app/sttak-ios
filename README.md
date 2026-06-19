# sttak-ios

> **sttak** — 주식 초보자를 위한 "투자 학습 + 모의투자" iOS 앱.
> 뉴스/공시를 호재·중립·악재로 정리하고 쉬운 한국어로 풀어 주며, 모의투자·차트학습·퀴즈로
> 안전하게 투자를 연습하게 합니다. 톤은 토스/케이뱅크식 신뢰감 + 따뜻한 종이톤.

현재 단계: **MVP 스켈레톤 (Mock-first)**. 외부 Spring 백엔드(BFF) 연동은 OpenAPI 스펙 확정 후 진행합니다.

## Tech Stack

- **SwiftUI** (iOS 17+), **Swift 6**, **Xcode 26.x**
- 아키텍처: MVVM + 얇은 UseCase + Repository (상세: `docs/ARCHITECTURE.md`)
- 프로젝트 관리: **XcodeGen** (`project.yml`이 단일 진실원, `.xcodeproj`는 생성물)
- 차트: Swift Charts (렌더러는 protocol로 분리)

## 사전 준비 (최초 1회)

```bash
# 1) Xcode를 명령행 도구로 선택 (관리자 비밀번호 입력 필요)
sudo xcode-select -s /Applications/Xcode.app

# 2) XcodeGen 설치 (Homebrew)
brew install xcodegen
```

## 빌드 & 실행

```bash
# 1) 프로젝트 파일 생성 (project.yml → sttak.xcodeproj)
xcodegen generate

# 2) Xcode로 열기
open sttak.xcodeproj
```

Xcode에서 상단 기기 선택을 **iPhone 시뮬레이터**로 두고 **⌘R** 로 실행하면 종이톤 배경에
워드마크가 뜨는 최소 화면이 표시됩니다. (자세한 초보자용 단계는 작업 로그/대화 참고)

> 명령행 빌드(선택): `xcodebuild -project sttak.xcodeproj -scheme sttak \`
> `-destination 'platform=iOS Simulator,name=iPhone 16' build`

## 폴더 구조 개요

```
App/        @main 진입점, RootView, AppContainer(DI) — 라우팅 골격
Core/       DesignSystem(토큰·공용 컴포넌트) · Networking · Persistence · Common
Domain/     Entities · ValueObjects · Indicators(지표/신호) · UseCases  (순수 Swift)
Data/       Repositories(구현) · Remote(DTO·매핑) · Mock(서버 없이 구동)
Features/   화면 단위: Onboarding/Home/ChartLearning/Quiz/Ranking/My/Chat
Resources/  폰트·Assets·Localizable
Tests/      DomainTests · DataTests · FeatureTests
docs/       ARCHITECTURE.md(설계) · design_handoff/(디자인 의도·토큰·화면 스펙)
```

> 폴더는 MVP 진행에 따라 추가됩니다. 현재 스켈레톤에는 `App/`만 존재합니다.
> 새 폴더는 `project.yml`의 `sources`에 등록한 뒤 `xcodegen generate` 하세요.

## 문서

- **`CLAUDE.md`** — AI 협업·작업 규칙, 빌드 타깃, 컨벤션의 단일 기준.
- **`docs/ARCHITECTURE.md`** — 확정 아키텍처·도메인·커밋 순서·결정 로그.
- **`docs/design_handoff/`** — 디자인 의도·토큰·화면 스펙 (프로토타입 HTML은 참고용).

## Branch Strategy

- `main`: 운영 배포 기준 브랜치
- `develop`: 개발 통합 브랜치
- `feature/*`: 기능 개발 브랜치
- `release/*` · `hotfix/*`: 배포/긴급 수정 (실제 배포 시점에 도입)

커밋 컨벤션: Conventional Commits (`feat`, `fix`, `docs`, `refactor`, `test`, `chore` …).
