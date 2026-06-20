import SwiftUI

/// 뉴스 상세 시트. 3탭(쉬운 풀이 / 원문 / AI에게 묻기). 커밋 4 BottomSheet 위에 표시된다.
struct NewsDetailView: View {
    @Bindable var viewModel: NewsDetailViewModel
    let onClose: () -> Void

    private let now = Date()

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            headerBlock
            tabContent
        }
        .containerRelativeFrame(.vertical) { height, _ in height * 0.86 }
        .task { await viewModel.loadSuggestions() }
        .onDisappear { viewModel.cancelStreaming() }
    }

    // MARK: 핸들 + 헤더
    private var dragHandle: some View {
        Capsule()
            .fill(AppColor.controlBorder)
            .frame(width: 38, height: 5)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xs)
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Badge(viewModel.news.sentiment.label, kind: viewModel.news.sentiment.badgeKind)
                Text(viewModel.stockName)
                    .font(AppFont.bodyStrong)
                    .foregroundStyle(AppColor.inkSoft)
                Text("· \(Formatters.relativeTime(viewModel.news.publishedAt, reference: now))")
                    .font(AppFont.metaCaption)
                    .foregroundStyle(AppColor.textMuted2)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppColor.textMuted)
                        .frame(width: 32, height: 32)
                        .background(AppColor.surfaceChip)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Text(viewModel.news.title)
                .font(AppFont.focusCardTitle)
                .foregroundStyle(AppColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            SegmentedControl(["쉬운 풀이", "원문", "AI에게 묻기"], selection: tabBinding, style: .ink)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.bottom, AppSpacing.md)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .easy: EasyTab(viewModel: viewModel)
        case .origin: OriginTab(news: viewModel.news, reference: now)
        case .ai: AITab(viewModel: viewModel)
        }
    }

    private var tabBinding: Binding<Int> {
        Binding(
            get: { viewModel.selectedTab.rawValue },
            set: { viewModel.selectedTab = NewsDetailViewModel.Tab(rawValue: $0) ?? .easy }
        )
    }
}

// MARK: - 쉬운 풀이 탭
private struct EasyTab: View {
    @Bindable var viewModel: NewsDetailViewModel
    private var news: NewsItem { viewModel.news }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                sectionLabel("이 소식, 무슨 뜻인가요?")
                oneLineBox
                Text(news.summary)
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.inkSoft)
                    .lineSpacing(5)
                    .padding(.bottom, AppSpacing.xxl)

                sectionLabel("왜 중요한가요?")
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    ForEach(Array(news.whyPoints.enumerated()), id: \.offset) { _, point in
                        HStack(alignment: .top, spacing: AppSpacing.sm) {
                            Circle().fill(AppColor.accent).frame(width: 5, height: 5).padding(.top, 7)
                            Text(point).font(AppFont.body).foregroundStyle(AppColor.inkSoft)
                        }
                    }
                }
                .padding(.bottom, AppSpacing.lg)
                reasonBox.padding(.bottom, AppSpacing.xxl)

                sectionLabel("알아두면 좋은 용어")
                VStack(spacing: AppSpacing.sm) {
                    ForEach(Array(news.terms.enumerated()), id: \.offset) { index, term in
                        TermRow(term: term, isOpen: viewModel.openTerms.contains(index)) {
                            withAnimation(.snappy) { viewModel.toggleTerm(index) }
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.lg)
        }
    }

    private var oneLineBox: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: "sparkles").font(.system(size: 16)).foregroundStyle(AppColor.accent).padding(.top, 2)
            Text(news.easy).font(AppFont.listItem).foregroundStyle(AppColor.accentDeeper).lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .background(AppColor.accentTintSoft)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .padding(.bottom, AppSpacing.md)
    }

    private var reasonBox: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Circle().fill(news.sentiment.color).frame(width: 8, height: 8)
                Text(news.sentiment.softNewsLabel).font(AppFont.bodyStrong).foregroundStyle(AppColor.ink)
            }
            Text(news.reason).font(AppFont.bodyStrong).foregroundStyle(AppColor.inkSoft).lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColor.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.row))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppFont.metaCaption)
            .foregroundStyle(AppColor.textMuted2)
            .padding(.bottom, AppSpacing.sm)
    }
}

private struct TermRow: View {
    let term: Term
    let isOpen: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "book").font(.system(size: 13)).foregroundStyle(AppColor.accent)
                        Text(term.term).font(AppFont.newsTitle).foregroundStyle(AppColor.ink)
                    }
                    Spacer()
                    Image(systemName: isOpen ? "minus" : "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColor.textMuted2)
                }
                if isOpen {
                    Text(term.definition)
                        .font(AppFont.bodyStrong)
                        .foregroundStyle(AppColor.inkSoft)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(AppSpacing.md)
            .background(AppColor.backgroundPrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.row))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 원문 탭
private struct OriginTab: View {
    let news: NewsItem
    let reference: Date

    @Environment(\.openURL) private var openURL

    /// 핸드오프의 장식용 블러 티저(원문 일부 흐림 처리).
    private let blurFiller = "증권가는 이번 분기 영업이익이 시장 기대치를 소폭 웃돌 것으로 전망하고 있으며, 메모리 업황 회복 속도와 파운드리 수주 흐름이 핵심 변수로 꼽힌다. 관계자는 추가적인 가격 협상이 이어지고 있다고 전했다."

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: AppSpacing.md) {
                        Text(String(news.source.prefix(2)))
                            .font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted)
                            .frame(width: 40, height: 40)
                            .background(AppColor.surfaceChip)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.chip))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(news.source).font(AppFont.newsTitle).foregroundStyle(AppColor.ink)
                            Text("\(Formatters.relativeTime(news.publishedAt, reference: reference)) 게시")
                                .font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted2)
                        }
                        Spacer()
                    }
                    .padding(.bottom, AppSpacing.xl)

                    Text("원문 미리보기").font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted2)
                        .padding(.bottom, AppSpacing.sm)
                    Text(news.lead).font(AppFont.body).foregroundStyle(AppColor.ink).lineSpacing(5)
                        .padding(.bottom, AppSpacing.md)

                    blurredPreview.padding(.bottom, AppSpacing.lg)
                    caveatBox
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.lg)
            }

            externalLinkButton
        }
    }

    private var blurredPreview: some View {
        Text(blurFiller)
            .font(AppFont.bodyStrong)
            .foregroundStyle(AppColor.inkSoft)
            .lineSpacing(6)
            .blur(radius: 5)
            .opacity(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Text("전체 내용은 원문에서 확인하세요")
                    .font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted)
                    .padding(.bottom, AppSpacing.sm)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.row))
    }

    private var caveatBox: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: "info.circle").font(.system(size: 13)).foregroundStyle(AppColor.textMuted2)
            Text("쉬운 풀이는 이해를 돕기 위해 정리한 내용이에요. 투자 판단 전 원문도 함께 확인해 주세요.")
                .font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted).lineSpacing(3)
        }
        .padding(AppSpacing.md)
        .background(AppColor.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.chip))
    }

    private var externalLinkButton: some View {
        Button {
            if let url = news.originalURL { openURL(url) }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Text("\(news.source) 원문 보기").font(AppFont.listItem)
                Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(AppColor.accent)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.row))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.xl)
        .overlay(alignment: .top) { Rectangle().fill(AppColor.hairline2).frame(height: 1) }
    }
}

// MARK: - AI에게 묻기 탭
private struct AITab: View {
    @Bindable var viewModel: NewsDetailViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: AppSpacing.md) {
                        ForEach(viewModel.messages) { turn in
                            ChatBubble(
                                turn: turn,
                                showTyping: turn.role == .assistant && turn.text.isEmpty && viewModel.isStreaming
                            )
                            .id(turn.id)
                        }
                        if case let .error(message) = viewModel.streamingState {
                            errorRow(message)
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.lg)
                }
                .onChange(of: viewModel.messages.last?.text) {
                    if let last = viewModel.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            inputArea
        }
    }

    private func errorRow(_ message: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Text(message).font(AppFont.bodyStrong).foregroundStyle(AppColor.textMuted)
            Button("다시 시도") { viewModel.retry() }
                .font(AppFont.bodyStrong).foregroundStyle(AppColor.accentDeep)
        }
        .frame(maxWidth: .infinity)
    }

    private var inputArea: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("이런 점이 궁금하다면").font(AppFont.microCaption).foregroundStyle(AppColor.textMuted2)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(viewModel.suggestedQuestions, id: \.self) { question in
                        Button { viewModel.ask(question) } label: {
                            Pill(question, style: .accentSoft)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isStreaming)
                    }
                }
            }
            HStack(spacing: AppSpacing.sm) {
                TextField("궁금한 점을 입력해 보세요", text: $viewModel.chatInput)
                    .font(AppFont.newsTitle)
                    .foregroundStyle(AppColor.ink)
                    .submitLabel(.send)
                    .onSubmit { viewModel.sendFree() }
                Button { viewModel.sendFree() } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(AppColor.accent)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.chipSmall))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isStreaming)
            }
            .padding(.leading, AppSpacing.md)
            .padding(.trailing, AppSpacing.xs)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColor.surfaceChip)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.row))
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.xl)
        .overlay(alignment: .top) { Rectangle().fill(AppColor.hairline2).frame(height: 1) }
    }
}

private struct ChatBubble: View {
    let turn: NewsDetailViewModel.ChatTurn
    let showTyping: Bool

    private var isUser: Bool { turn.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            Group {
                if showTyping {
                    TypingIndicator()
                } else {
                    Text(turn.text).font(AppFont.bodyStrong).lineSpacing(4)
                }
            }
            .foregroundStyle(isUser ? .white : AppColor.ink)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm + 2)
            .background(isUser ? AppColor.accent : AppColor.surfaceChip)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            if !isUser { Spacer(minLength: 40) }
        }
    }
}

/// 점 3개가 깜빡이는 타이핑 인디케이터.
private struct TypingIndicator: View {
    @State private var phase = 0.0
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(AppColor.textMuted2)
                    .frame(width: 6, height: 6)
                    .opacity(phase == Double(i) ? 1 : 0.3)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever()) { phase = 2 }
        }
    }
}
