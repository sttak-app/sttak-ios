# 폰트 설치 안내 (Pretendard · Space Grotesk)

이 앱은 본문/한글에 **Pretendard**, 숫자/지표에 **Space Grotesk**를 사용합니다.
폰트 파일은 **라이선스/용량 문제로 레포에 커밋하지 않습니다.** 아래 3단계를 완료해야
실제로 렌더됩니다. (완료 전에는 `Font.custom`이 조용히 시스템 폰트로 폴백 — 크기/굵기는 유지)

## 1) 폰트 파일 받아서 이 폴더에 넣기

`Resources/Fonts/` 에 아래 파일들을 넣습니다(`.otf` 또는 `.ttf`).

**Pretendard** — https://github.com/orioncactus/pretendard (릴리스의 `Pretendard-*.otf`)
- `Pretendard-Regular.otf`
- `Pretendard-Medium.otf`
- `Pretendard-SemiBold.otf`
- `Pretendard-Bold.otf`

**Space Grotesk** — https://fonts.google.com/specimen/Space+Grotesk (또는 https://github.com/floriankarsten/space-grotesk)
- `SpaceGrotesk-Regular.ttf`
- `SpaceGrotesk-Medium.ttf`
- `SpaceGrotesk-SemiBold.ttf`
- `SpaceGrotesk-Bold.ttf`

> 파일의 **PostScript 이름**이 `Typography.swift`의 이름(`Pretendard-Bold`,
> `SpaceGrotesk-SemiBold` 등)과 일치해야 합니다. 다르면 Font Book에서 확인 후
> `Typography.swift`의 `pretendardName`/`spaceGroteskName`을 맞추세요.

## 2) project.yml 에 리소스 등록 → 재생성

`project.yml`의 `targets.sttak.sources`에 폰트 폴더를 추가합니다:

```yaml
    sources:
      - path: App
      - path: Core
      - path: Resources/Fonts   # ← 추가
```

그리고 Info.plist에 `UIAppFonts`(폰트 이름 등록)를 추가합니다. XcodeGen에서는 타깃
settings에 다음을 추가하면 됩니다:

```yaml
    info:
      path: App/Info.plist
      properties:
        UIAppFonts:
          - Pretendard-Regular.otf
          - Pretendard-Medium.otf
          - Pretendard-SemiBold.otf
          - Pretendard-Bold.otf
          - SpaceGrotesk-Regular.ttf
          - SpaceGrotesk-Medium.ttf
          - SpaceGrotesk-SemiBold.ttf
          - SpaceGrotesk-Bold.ttf
```

> 현재는 `GENERATE_INFOPLIST_FILE: YES`로 Info.plist를 자동 생성 중입니다. `UIAppFonts`를
> 넣으려면 위처럼 명시적 `info:` 블록으로 전환하거나, 빌드 설정에서 Info.plist를 관리하세요.

## 3) 재생성 후 빌드

```bash
xcodegen generate && open sttak.xcodeproj
```

DesignSystemGalleryView 프리뷰에서 글자가 Pretendard/Space Grotesk로 바뀌면 성공입니다.
