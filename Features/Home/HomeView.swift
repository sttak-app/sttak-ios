import SwiftUI

/// 홈 "3초 브리핑". 앱바 → 그리팅(무드 바) → 종목 스트립 → 포커스 카드(스와이프) → 도트.
struct HomeView: View {
    @Environment(\.container) private var container
    @State private var viewModel: HomeViewModel?
    @State private var detailViewModel: NewsDetailViewModel?
    @State private var chatViewModel: ChatViewModel?
    @State private var showChat = false

    var body: some View {
        ZStack {
            AppColor.backgroundPrimary.ignoresSafeArea()
            if let viewModel {
                content(viewModel)
            } else {
                ProgressView().tint(AppColor.accent)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if viewModel != nil { aiButton }
        }
        .task {
            if viewModel == nil {
                viewModel = container.makeHomeViewModel()
                await viewModel?.load()
            }
        }
        .bottomSheet(isPresented: sheetBinding) {
            if let detailViewModel {
                NewsDetailView(viewModel: detailViewModel, onClose: { viewModel?.dismissNewsDetail() })
            }
        }
        .bottomSheet(isPresented: $showChat) {
            if let chatViewModel {
                ChatView(viewModel: chatViewModel, onClose: { showChat = false })
            }
        }
        .onChange(of: viewModel?.presentedNews?.id) { _, newID in
            if newID != nil, let presented = viewModel?.presentedNews {
                detailViewModel = container.makeNewsDetailViewModel(news: presented.news, stockName: presented.stockName)
            }
        }
    }

    /// 떠있는 "AI에게 묻기" 버튼(우하단). 탭 → 공용 챗봇 시트.
    private var aiButton: some View {
        Button {
            if chatViewModel == nil { chatViewModel = container.makeChatViewModel() }
            showChat = true
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "sparkles").font(.system(size: 14)).foregroundStyle(AppColor.accentBright)
                Text("AI에게 묻기").font(AppFont.metaCaption).foregroundStyle(.white)
            }
            .padding(.horizontal, AppSpacing.md).padding(.vertical, AppSpacing.sm)
            .background(AppColor.ink.opacity(0.92), in: Capsule())
            .appShadow(AppShadow.card)
        }
        .buttonStyle(.plain)
        .padding(.trailing, AppSpacing.screenHorizontal)
        .padding(.bottom, AppSpacing.lg)
    }

    private var sheetBinding: Binding<Bool> {
        Binding(
            get: { viewModel?.presentedNews != nil },
            set: { if !$0 { viewModel?.dismissNewsDetail() } }
        )
    }

    @ViewBuilder
    private func content(_ viewModel: HomeViewModel) -> some View {
        VStack(spacing: 0) {
            AppBar(assetText: viewModel.assetText)
            switch viewModel.state {
            case .loading:
                centered { ProgressView().tint(AppColor.accent) }
            case .empty:
                centered {
                    Text("관심종목을 추가하면\n오늘의 브리핑을 보여드려요")
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.textMuted)
                        .multilineTextAlignment(.center)
                }
            case let .error(message):
                centered {
                    VStack(spacing: AppSpacing.md) {
                        Text(message).font(AppFont.body).foregroundStyle(AppColor.textMuted).multilineTextAlignment(.center)
                        Button("다시 시도") { Task { await viewModel.load() } }
                            .font(AppFont.ctaLabel)
                            .foregroundStyle(AppColor.accentDeep)
                    }
                }
            case let .loaded(briefing):
                loaded(briefing, viewModel: viewModel)
            }
        }
    }

    @ViewBuilder
    private func loaded(_ briefing: DailyBriefing, viewModel: HomeViewModel) -> some View {
        // 그리팅·스트립은 상단 고정, 포커스 카드 페이저가 남은 공간을 채우며 각 카드가 세로 스크롤(무한 스크롤).
        // 바깥 세로 ScrollView를 두면 카드 내부 세로 스크롤과 제스처가 충돌하므로 두지 않는다.
        VStack(spacing: 0) {
            GreetingView(briefing: briefing, isRefreshing: viewModel.isRefreshing) {
                Task { await viewModel.refresh() }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.md)

            StockStripView(
                stocks: briefing.stocks,
                focusIndex: viewModel.focusIndex,
                onSelect: { index in withAnimation(.snappy) { viewModel.setFocus(index) } }
            )
            .padding(.top, AppSpacing.lg)

            FocusPager(briefing: briefing, viewModel: viewModel)
                .padding(.top, AppSpacing.sm)
                .frame(maxHeight: .infinity)

            PageDots(count: briefing.stocks.count, index: viewModel.focusIndex)
                .padding(.vertical, AppSpacing.lg)
        }
    }

    private func centered<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack { Spacer(); content(); Spacer() }.frame(maxWidth: .infinity)
    }
}

// MARK: - 앱 바
private struct AppBar: View {
    let assetText: String
    var body: some View {
        HStack {
            HStack(spacing: AppSpacing.sm) {
                ReticleLogo(size: 26)
                Text("sttak").font(AppFont.homeGreeting).kerning(-0.6).foregroundStyle(AppColor.ink)
            }
            Spacer()
            if !assetText.isEmpty {
                Pill(style: .surface) {
                    HStack(spacing: AppSpacing.xs) {
                        Text("보유 자산").font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted)
                        Text(assetText).font(AppFont.number(13)).foregroundStyle(AppColor.accentDeep)
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.sm)
    }
}

// MARK: - 그리팅 + 무드 바
private struct GreetingView: View {
    let briefing: DailyBriefing
    let isRefreshing: Bool
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(Formatters.koreanDate(Date())) · 오늘의 브리핑")
                .font(AppFont.metaCaption)
                .foregroundStyle(AppColor.textMuted2)
                .padding(.bottom, AppSpacing.xs)

            Text(moodText)
                .font(AppFont.homeGreeting)
                .foregroundStyle(AppColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("오늘 새 소식 \(briefing.totalNewsCount)건")
                    .font(AppFont.metaCaption)
                    .foregroundStyle(AppColor.textMuted2)
                Spacer()
                Button(action: onRefresh) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(isRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                        Text("새로고침").font(AppFont.metaCaption)
                    }
                    .foregroundStyle(AppColor.textMuted2)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, AppSpacing.sm)

            MoodBar(breakdown: briefing.breakdown)
        }
    }

    private var moodText: String {
        switch briefing.mood {
        case .positive: return "오늘 관심종목은 대체로 긍정적이에요"
        case .cautious: return "오늘은 조심해서 볼 소식이 있어요"
        case .mixed: return "긍정과 주의가 섞여 있는 하루예요"
        }
    }
}

/// 무드 바(호재 빨강 / 중립 회색 / 악재 파랑 비율).
private struct MoodBar: View {
    let breakdown: SentimentBreakdown

    var body: some View {
        GeometryReader { geo in
            let total = CGFloat(max(breakdown.total, 1))
            let width = geo.size.width
            HStack(spacing: 2) {
                segment(width: width * CGFloat(breakdown.positive) / total, color: AppColor.priceUp)
                segment(width: width * CGFloat(breakdown.neutral) / total, color: AppColor.controlBorder)
                segment(width: width * CGFloat(breakdown.negative) / total, color: AppColor.priceDown)
            }
        }
        .frame(height: 7)
        .background(AppColor.segmentTrack)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private func segment(width: CGFloat, color: Color) -> some View {
        if width > 0 { color.frame(width: width) }
    }
}

// MARK: - 종목 스트립
private struct StockStripView: View {
    let stocks: [StockBriefing]
    let focusIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(Array(stocks.enumerated()), id: \.offset) { index, sb in
                    let selected = index == focusIndex
                    Button { onSelect(index) } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Circle().fill(sb.dominantSentiment.color).frame(width: 8, height: 8)
                            Text(sb.stock.name)
                                .font(AppFont.newsTitle)
                                .foregroundStyle(selected ? .white : AppColor.ink)
                            if let quote = sb.quote, quote.price.amount > 0 {
                                Text(Formatters.signedPercent(quote.changePercent))
                                    .font(AppFont.number(12))
                                    .foregroundStyle(selected ? .white.opacity(0.92) : (quote.changePercent >= 0 ? AppColor.priceUp : AppColor.priceDown))
                            }
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.sm + 2)
                        .background(selected ? AppColor.ink : AppColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.row))
                        .appShadow(selected ? .init(color: .clear, radius: 0, x: 0, y: 0) : AppShadow.card)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
        }
    }
}

// MARK: - 포커스 카드 페이저(스와이프)
private struct FocusPager: View {
    let briefing: DailyBriefing
    let viewModel: HomeViewModel

    var body: some View {
        TabView(selection: focusBinding) {
            ForEach(Array(briefing.stocks.enumerated()), id: \.offset) { index, sb in
                // 각 페이지를 세로 ScrollView로 감싸 카드 내부에서 스크롤 + 하단 도달 시 더 불러오기.
                ScrollView(showsIndicators: false) {
                    FocusCardView(
                        briefing: sb,
                        extraNews: viewModel.extraNews(for: sb.id),
                        hasMore: viewModel.hasMoreNews(for: sb.id),
                        isLoadingMore: viewModel.isLoadingMore(for: sb.id),
                        onLoadMore: { Task { await viewModel.loadMore(for: sb.id) } },
                        onNewsTap: { news in viewModel.openNewsDetail(stockName: sb.stock.name, news: news) }
                    )
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.lg)
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private var focusBinding: Binding<Int> {
        Binding(get: { viewModel.focusIndex }, set: { viewModel.setFocus($0) })
    }
}

// MARK: - 도트 인디케이터
private struct PageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: AppSpacing.xs + 3) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? AppColor.accent : AppColor.controlBorder)
                    .frame(width: i == index ? 20 : 7, height: 7)
                    .animation(.snappy, value: index)
            }
        }
    }
}
