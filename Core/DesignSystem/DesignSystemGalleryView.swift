#if DEBUG
import SwiftUI

// MARK: - DesignSystemGalleryView (DEBUG 전용)
//
// 색 팔레트·타입 스케일·ReticleLogo 를 한 화면에 렌더해 핸드오프와 눈으로 대조하기 위한
// 미리보기 갤러리. 프로덕션 빌드(release)에는 포함되지 않는다.
// Xcode 에서 이 파일을 열고 Canvas(⌥⌘↩) 의 Preview 로 확인한다.
struct DesignSystemGalleryView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                logoSection
                colorSection
                typographySection
            }
            .padding(AppSpacing.screenHorizontal)
        }
        .background(AppColor.backgroundPrimary.ignoresSafeArea())
    }

    // MARK: 로고

    private var logoSection: some View {
        sectionCard("ReticleLogo") {
            HStack(alignment: .bottom, spacing: AppSpacing.xxl) {
                logoSample(78)
                logoSample(52)
                logoSample(26)
            }
            HStack(spacing: AppSpacing.sm) {
                ReticleLogo(size: 26)
                Text("sttak")
                    .font(AppFont.splashWordmark)
                    .kerning(-1.2)
                    .foregroundStyle(AppColor.ink)
            }
            .padding(.top, AppSpacing.sm)
        }
    }

    private func logoSample(_ size: CGFloat) -> some View {
        VStack(spacing: AppSpacing.xs) {
            ReticleLogo(size: size)
            Text("\(Int(size))")
                .font(AppFont.microCaption)
                .foregroundStyle(AppColor.textMuted)
        }
    }

    // MARK: 색 팔레트

    private var colorSection: some View {
        sectionCard("Colors") {
            swatchRow("베이스 / 중립", [
                ("backgroundApp", AppColor.backgroundApp),
                ("backgroundPrimary", AppColor.backgroundPrimary),
                ("surface", AppColor.surface),
                ("surfaceAlt", AppColor.surfaceAlt),
                ("surfaceChip", AppColor.surfaceChip),
            ])
            swatchRow("텍스트 / 구분선", [
                ("ink", AppColor.ink),
                ("inkSoft", AppColor.inkSoft),
                ("textMuted", AppColor.textMuted),
                ("textMuted2", AppColor.textMuted2),
                ("hairline", AppColor.hairline),
            ])
            swatchRow("브랜드 (틸)", [
                ("accent", AppColor.accent),
                ("accentDeep", AppColor.accentDeep),
                ("accentBright", AppColor.accentBright),
                ("accentTint", AppColor.accentTint),
                ("accentTintBorder", AppColor.accentTintBorder),
            ])
            swatchRow("감정 (배지)", [
                ("posit.", AppColor.sentimentPositive),
                ("pos.tint", AppColor.sentimentPositiveTint),
                ("neg.", AppColor.sentimentNegative),
                ("neg.tint", AppColor.sentimentNegativeTint),
                ("neutral", AppColor.sentimentNeutral),
            ])
            swatchRow("등락 / 무드", [
                ("priceUp", AppColor.priceUp),
                ("priceDown", AppColor.priceDown),
                ("priceFlat", AppColor.priceFlat),
            ])
            swatchRow("퀴즈 / 외부", [
                ("correct", AppColor.correct),
                ("wrong", AppColor.wrong),
                ("kakao", AppColor.kakao),
            ])
            swatchRow("리그", [
                ("bronze", AppColor.leagueBronze),
                ("silver", AppColor.leagueSilver),
                ("gold", AppColor.leagueGold),
                ("platinum", AppColor.leaguePlatinum),
                ("diamond", AppColor.leagueDiamond),
            ])
        }
    }

    private func swatchRow(_ title: String, _ items: [(String, Color)]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppFont.metaCaption)
                .foregroundStyle(AppColor.textMuted)
            HStack(spacing: AppSpacing.sm) {
                ForEach(items, id: \.0) { name, color in
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: AppRadius.chipSmall)
                            .fill(color)
                            .frame(width: 52, height: 40)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.chipSmall)
                                    .stroke(AppColor.hairline, lineWidth: 1)
                            )
                        Text(name)
                            .font(AppFont.microCaption)
                            .foregroundStyle(AppColor.textMuted2)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    // MARK: 타이포

    private var typographySection: some View {
        sectionCard("Typography") {
            typeSample("splashWordmark 40/700", AppFont.splashWordmark)
            typeSample("loginHeadline 27/700", AppFont.loginHeadline)
            typeSample("screenTitle 24/700", AppFont.screenTitle)
            typeSample("homeGreeting 22/700", AppFont.homeGreeting)
            typeSample("focusCardTitle 19/700", AppFont.focusCardTitle)
            typeSample("sectionHeader 16/700", AppFont.sectionHeader)
            typeSample("listItem 15/600", AppFont.listItem)
            typeSample("newsTitle 14.5/600", AppFont.newsTitle)
            typeSample("body 14/500", AppFont.body)
            typeSample("metaCaption 12.5/600", AppFont.metaCaption)
            typeSample("badge 11.5/700", AppFont.badge)

            Divider().padding(.vertical, AppSpacing.xs)
            Text("숫자 — Space Grotesk")
                .font(AppFont.metaCaption)
                .foregroundStyle(AppColor.textMuted)
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.lg) {
                Text("10,000,000").font(AppFont.numberHero)
                Text("+3.21%").font(AppFont.numberLarge).foregroundStyle(AppColor.priceUp)
            }
            .foregroundStyle(AppColor.ink)
        }
    }

    private func typeSample(_ label: String, _ font: Font) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(AppFont.microCaption)
                .foregroundStyle(AppColor.textMuted2)
            Text("데이터로 시작하는 첫 투자 sttak")
                .font(font)
                .foregroundStyle(AppColor.ink)
        }
    }

    // MARK: 공통 카드

    private func sectionCard<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(title)
                .font(AppFont.sectionHeader)
                .foregroundStyle(AppColor.ink)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.cardPadding)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColor.hairline, lineWidth: 1)
        )
        .appShadow(AppShadow.card)
    }
}

#Preview("Design System Gallery") {
    DesignSystemGalleryView()
}
#endif
