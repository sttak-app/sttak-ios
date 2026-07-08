import SwiftUI

/// 포커스 종목 카드(스와이프 1장). 핸드오프: 컴팩트 헤더(가격은 보조) + 주목 소식 2건(쉬운 풀이) + 그 외 소식.
struct FocusCardView: View {
    let briefing: StockBriefing
    let onNewsTap: (NewsItem) -> Void

    private let now = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Text("오늘 주목할 소식")
                .font(AppFont.bodyStrong)
                .foregroundStyle(AppColor.ink)
                .padding(.bottom, AppSpacing.md)

            if briefing.primaryNews.isEmpty {
                Text("오늘은 새 소식이 없어요")
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.textMuted)
                    .padding(.vertical, AppSpacing.md)
            } else {
                ForEach(Array(briefing.primaryNews.enumerated()), id: \.offset) { _, news in
                    PrimaryNewsRow(news: news, reference: now) { onNewsTap(news) }
                }
            }

            if !briefing.otherNews.isEmpty {
                Text("그 외 소식 \(briefing.otherNews.count)건")
                    .font(AppFont.metaCaption)
                    .foregroundStyle(AppColor.textMuted2)
                    .padding(.top, AppSpacing.xs)
                ForEach(Array(briefing.otherNews.enumerated()), id: \.offset) { _, news in
                    OtherNewsRow(news: news, reference: now) { onNewsTap(news) }
                }
            }
        }
        .padding(AppSpacing.xl)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.banner))
        .appShadow(AppShadow.card)
    }

    private var header: some View {
        HStack(spacing: AppSpacing.sm) {
            Text(briefing.stock.name)
                .font(AppFont.focusCardTitle)
                .foregroundStyle(AppColor.ink)
            if !briefing.stock.sector.isEmpty {
                Pill(briefing.stock.sector, style: .neutral)
            }
            Spacer(minLength: AppSpacing.sm)
            if let quote = briefing.quote, quote.price.amount > 0 {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                    Text(Formatters.grouped(quote.price.amount))
                        .font(AppFont.number(14))
                        .foregroundStyle(AppColor.inkSoft)
                    Text(Formatters.signedPercent(quote.changePercent))
                        .font(AppFont.number(13))
                        .foregroundStyle(quote.changePercent >= 0 ? AppColor.priceUp : AppColor.priceDown)
                }
            }
        }
        .padding(.bottom, AppSpacing.lg)
    }
}

/// 주목 소식 1건(배지 + 제목 + 쉬운 풀이 박스).
private struct PrimaryNewsRow: View {
    let news: NewsItem
    let reference: Date
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.xs) {
                    Badge(news.sentiment.label, kind: news.sentiment.badgeKind)
                    Text("\(Formatters.relativeTime(news.publishedAt, reference: reference)) · \(news.source)")
                        .font(AppFont.microCaption)
                        .foregroundStyle(AppColor.textMuted2)
                }

                Text(news.title)
                    .font(AppFont.listItem)
                    .foregroundStyle(AppColor.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColor.accent)
                        .padding(.top, 2)
                    Text(news.easy)
                        .font(AppFont.bodyStrong)
                        .foregroundStyle(AppColor.accentDeeper)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(AppSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.accentTintSoft)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.chipSmall))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, AppSpacing.md)
            .overlay(alignment: .bottom) {
                Rectangle().fill(AppColor.divider).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

/// 그 외 소식 1줄(점 + 제목 + 시간 + 화살표).
private struct OtherNewsRow: View {
    let news: NewsItem
    let reference: Date
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.md) {
                Circle().fill(news.sentiment.color).frame(width: 7, height: 7)
                Text(news.title)
                    .font(AppFont.newsTitle)
                    .foregroundStyle(AppColor.ink)
                    .lineLimit(1)
                Spacer(minLength: AppSpacing.sm)
                Text(Formatters.relativeTime(news.publishedAt, reference: reference))
                    .font(AppFont.microCaption)
                    .foregroundStyle(AppColor.textMuted2)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppColor.textMuted2)
            }
            .padding(.vertical, AppSpacing.md)
            .overlay(alignment: .bottom) {
                Rectangle().fill(AppColor.hairline2).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
