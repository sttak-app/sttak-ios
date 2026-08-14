import SwiftUI

/// 포커스 종목 카드(스와이프 1장). 컴팩트 헤더(가격은 보조) + 모든 소식을 동일한 리치 카드(배지+쉬운 풀이)로.
/// 세로 스크롤로 더 내리면 커서 페이지네이션으로 계속 이어 붙는다(무한 스크롤).
struct FocusCardView: View {
    let briefing: StockBriefing
    let extraNews: [NewsItem]        // 첫 페이지 이후 누적된 뉴스
    let hasMore: Bool                // 더 불러올 뉴스가 있는지
    let isLoadingMore: Bool          // 더보기 진행 중
    let onLoadMore: () -> Void
    let onNewsTap: (NewsItem) -> Void

    private let now = Date()

    /// 전체 소식 = 첫 페이지(중요도순) + 이후 커서로 받아온 페이지들.
    private var allNews: [NewsItem] { briefing.news + extraNews }

    var body: some View {
        // LazyVStack: 아래 행들은 스크롤로 가까워질 때 생성 → 하단 로더 onAppear가 "스크롤 도달" 시에만 발화.
        LazyVStack(alignment: .leading, spacing: 0) {
            header

            Text("오늘의 소식")
                .font(AppFont.bodyStrong)
                .foregroundStyle(AppColor.ink)
                .padding(.bottom, AppSpacing.md)

            if allNews.isEmpty {
                Text("오늘은 새 소식이 없어요")
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.textMuted)
                    .padding(.vertical, AppSpacing.md)
            } else {
                ForEach(Array(allNews.enumerated()), id: \.offset) { _, news in
                    NewsRow(news: news, reference: now) { onNewsTap(news) }
                }
            }

            if hasMore {
                loadMoreFooter
            }
        }
        .padding(AppSpacing.xl)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.banner))
        .appShadow(AppShadow.card)
    }

    /// 하단 로더 — 스크롤로 나타나면 다음 페이지를 요청한다.
    private var loadMoreFooter: some View {
        HStack {
            Spacer()
            ProgressView()
                .tint(AppColor.accent)
                .opacity(isLoadingMore ? 1 : 0.4)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .onAppear { onLoadMore() }
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

/// 소식 1건(배지 + 제목 + 쉬운 풀이 박스). 모든 기사를 이 리치 카드로 통일.
private struct NewsRow: View {
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
