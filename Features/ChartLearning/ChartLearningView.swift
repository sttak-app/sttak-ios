import SwiftUI

/// 차트학습 화면. 캔들차트(기간/줌/팬) + 지표 오버레이 + 과거 신호/코치.
/// ⚠ Swift Charts 비의존 — ChartRenderer protocol에만 의존(확정 E10).
struct ChartLearningView: View {
    @Environment(\.container) private var container
    @State private var viewModel: ChartLearningViewModel?

    private let renderer: ChartRenderer = SwiftChartsRenderer()

    @State private var panBaseStart: Int?
    @State private var zoomBaseCount: Int?
    @State private var tradeViewModel: TradeViewModel?

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColor.backgroundPrimary.ignoresSafeArea()
            if let viewModel {
                content(viewModel)
                if viewModel.state == .loaded { tradeBar(viewModel) }
            } else {
                ProgressView().tint(AppColor.accent)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = container.makeChartLearningViewModel()
                await viewModel?.load()
            }
        }
        .bottomSheet(isPresented: tradeBinding) {
            if let tradeViewModel {
                TradeSheetView(viewModel: tradeViewModel, onClose: { viewModel?.dismissTrade() })
            }
        }
        .onChange(of: viewModel?.tradeIntent?.id) { _, newID in
            if newID != nil, let intent = viewModel?.tradeIntent {
                tradeViewModel = container.makeTradeViewModel(intent: intent) {
                    Task { await viewModel?.onTradeCompleted() }
                }
            }
        }
    }

    private var tradeBinding: Binding<Bool> {
        Binding(
            get: { viewModel?.tradeIntent != nil },
            set: { if !$0 { viewModel?.dismissTrade() } }
        )
    }

    // MARK: 트레이드 바
    private func tradeBar(_ viewModel: ChartLearningViewModel) -> some View {
        HStack(spacing: AppSpacing.sm) {
            if viewModel.heldQuantity > 0 {
                Text("보유 \(viewModel.heldQuantity)주")
                    .font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted)
                    .padding(.trailing, AppSpacing.xs)
            }
            tradeButton("매도", color: AppColor.priceDown) { viewModel.openSell() }
            tradeButton("매수", color: AppColor.priceUp) { viewModel.openBuy() }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.vertical, AppSpacing.md)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Rectangle().fill(AppColor.hairline2).frame(height: 1) }
    }

    private func tradeButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(AppFont.ctaLabel).foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(color).clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func content(_ viewModel: ChartLearningViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(viewModel)
                if viewModel.stocks.count > 1 { stockSelector(viewModel) }
                chartArea(viewModel).padding(.top, AppSpacing.md)
                periodSelector(viewModel)
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.lg)

                if let detail = viewModel.selectedSignalDetail {
                    SignalDetailCard(detail: detail).padding(.top, AppSpacing.md)
                } else if !viewModel.signalEvents.isEmpty {
                    signalHint.padding(.top, AppSpacing.md)
                }

                indicatorChips(viewModel).padding(.top, AppSpacing.lg)
                CoachCard(viewModel: viewModel).padding(.top, AppSpacing.md)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.bottom, 90) // 트레이드 바 회피
        }
    }

    // MARK: 헤더
    @ViewBuilder
    private func header(_ viewModel: ChartLearningViewModel) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(viewModel.selectedStock?.name ?? "차트학습")
                .font(AppFont.screenTitle).foregroundStyle(AppColor.ink)
            Spacer()
            if let quote = viewModel.quote {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                    Text(Formatters.grouped(quote.price.amount)).font(AppFont.numberLarge).foregroundStyle(AppColor.ink)
                    Text(Formatters.signedPercent(quote.changePercent))
                        .font(AppFont.number(14))
                        .foregroundStyle(quote.changePercent >= 0 ? AppColor.priceUp : AppColor.priceDown)
                }
            }
        }
        .padding(.top, AppSpacing.md)
    }

    // MARK: 종목 선택
    private func stockSelector(_ viewModel: ChartLearningViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(Array(viewModel.stocks.enumerated()), id: \.offset) { index, stock in
                    let selected = index == viewModel.selectedStockIndex
                    Button { Task { await viewModel.selectStock(index) } } label: {
                        Text(stock.name)
                            .font(AppFont.newsTitle)
                            .foregroundStyle(selected ? .white : AppColor.inkSoft)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                            .background(selected ? AppColor.accent : AppColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.chip))
                            .overlay(RoundedRectangle(cornerRadius: AppRadius.chip).stroke(selected ? .clear : AppColor.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, AppSpacing.md)
        }
    }

    // MARK: 차트
    @ViewBuilder
    private func chartArea(_ viewModel: ChartLearningViewModel) -> some View {
        GeometryReader { geo in
            Group {
                switch viewModel.state {
                case .loading:
                    centered { ProgressView().tint(AppColor.accent) }
                case let .error(message):
                    centered { Text(message).font(AppFont.body).foregroundStyle(AppColor.textMuted) }
                case .loaded:
                    renderer.candleChart(
                        viewModel.visibleCandles,
                        overlay: viewModel.chartOverlay,
                        onSelectCandle: { viewModel.selectCandle(at: $0) }
                    )
                    .gesture(panGesture(viewModel, width: geo.size.width))
                    .simultaneousGesture(zoomGesture(viewModel))
                }
            }
            .frame(width: geo.size.width, height: 236)
        }
        .frame(height: 236)
    }

    // MARK: 기간
    private func periodSelector(_ viewModel: ChartLearningViewModel) -> some View {
        SegmentedControl(
            ChartPeriod.allCases.map(\.label),
            selection: Binding(
                get: { ChartPeriod.allCases.firstIndex(of: viewModel.period) ?? 0 },
                set: { viewModel.selectPeriod(ChartPeriod.allCases[$0]) }
            ),
            style: .accent
        )
    }

    // MARK: 신호 힌트
    private var signalHint: some View {
        HStack(spacing: AppSpacing.sm) {
            Circle().fill(AppColor.accent).frame(width: 14, height: 14)
            Text("색칠된 구간이 과거에 이 신호가 나왔던 사례예요")
                .font(AppFont.bodyStrong).foregroundStyle(AppColor.textMuted)
        }
    }

    // MARK: 지표 칩
    private func indicatorChips(_ viewModel: ChartLearningViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: "sparkles").font(.system(size: 14)).foregroundStyle(AppColor.accent)
                Text("용어를 누르면, 과거에 그 신호가 통했던 구간을 차트에 표시해요")
                    .font(AppFont.bodyStrong).foregroundStyle(AppColor.inkSoft)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(IndicatorCopy.panelOrder, id: \.self) { kind in
                        let selected = viewModel.selectedIndicator == kind
                        Button { viewModel.selectIndicator(kind) } label: {
                            HStack(spacing: AppSpacing.xs) {
                                Circle().fill(IndicatorCopy.dotColor(kind)).frame(width: 8, height: 8)
                                Text(IndicatorCopy.label(kind)).font(AppFont.bodyStrong)
                            }
                            .foregroundStyle(selected ? .white : AppColor.inkSoft)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                            .background(selected ? AppColor.ink : AppColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.chip))
                            .appShadow(selected ? .init(color: .clear, radius: 0, x: 0, y: 0) : AppShadow.card)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, AppSpacing.xs)
            }
        }
    }

    // MARK: 제스처
    private func panGesture(_ viewModel: ChartLearningViewModel, width: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if panBaseStart == nil { panBaseStart = viewModel.viewport.start }
                let candleWidth = width / CGFloat(max(viewModel.viewport.count, 1))
                let delta = Int((-value.translation.width / max(candleWidth, 1)).rounded())
                viewModel.scroll(toStart: (panBaseStart ?? 0) + delta)
            }
            .onEnded { _ in panBaseStart = nil }
    }

    private func zoomGesture(_ viewModel: ChartLearningViewModel) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if zoomBaseCount == nil { zoomBaseCount = viewModel.viewport.count }
                let base = Double(zoomBaseCount ?? viewModel.viewport.count)
                viewModel.zoom(toCount: Int((base / value.magnification).rounded()))
            }
            .onEnded { _ in zoomBaseCount = nil }
    }

    private func centered<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack { Spacer(); content(); Spacer() }.frame(maxWidth: .infinity)
    }
}

// MARK: - 코치 카드
private struct CoachCard: View {
    @Bindable var viewModel: ChartLearningViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15)).foregroundStyle(.white)
                    .frame(width: 30, height: 30).background(AppColor.accent)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.chipSmall))
                Text(IndicatorCopy.coachTitle(viewModel.selectedIndicator))
                    .font(AppFont.listItem).foregroundStyle(AppColor.ink)
                Spacer()
                Button { viewModel.toggleExplanation() } label: {
                    Text(viewModel.explanationOpen ? "설명 숨기기" : "설명 보기")
                        .font(AppFont.metaCaption).foregroundStyle(AppColor.accentDeep)
                        .padding(.horizontal, AppSpacing.sm).padding(.vertical, AppSpacing.xs)
                        .background(AppColor.accentTintSoft).clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if viewModel.explanationOpen {
                Text(IndicatorCopy.coachBody(viewModel.selectedIndicator))
                    .font(AppFont.body).foregroundStyle(AppColor.inkSoft).lineSpacing(4)
                    .padding(.top, AppSpacing.md)
                if viewModel.selectedIndicator == .info, let f = viewModel.fundamentals {
                    fundamentalsRow(f).padding(.top, AppSpacing.md)
                }
            }

            if let reading = viewModel.currentReading {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Text("지금").font(AppFont.microCaption).foregroundStyle(AppColor.accentDeep)
                        .padding(.horizontal, AppSpacing.sm).padding(.vertical, 3)
                        .background(AppColor.accentTint).clipShape(RoundedRectangle(cornerRadius: AppRadius.badge))
                    Text(reading).font(AppFont.bodyStrong).foregroundStyle(AppColor.inkSoft).lineSpacing(2)
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.backgroundPrimary)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.row))
                .padding(.top, AppSpacing.md)
            }

            if !viewModel.signalEvents.isEmpty {
                eventList.padding(.top, AppSpacing.lg)
            }
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.cardLarge))
        .appShadow(AppShadow.card)
    }

    private func fundamentalsRow(_ f: StockFundamentals) -> some View {
        HStack(spacing: AppSpacing.sm) {
            fundamentalCell("시가총액", f.marketCap)
            fundamentalCell("PER", f.per)
            fundamentalCell("PBR", f.pbr)
        }
    }

    private func fundamentalCell(_ title: String, _ value: String) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Text(title).font(AppFont.microCaption).foregroundStyle(AppColor.textMuted2)
            Text(value).font(AppFont.number(14)).foregroundStyle(AppColor.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .background(AppColor.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.chip))
    }

    private var eventList: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("차트에 표시된 과거 사례").font(AppFont.bodyStrong).foregroundStyle(AppColor.inkSoft)
            Text("번호를 누르면 그 시점으로 차트가 이동해요").font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted2)
            ForEach(viewModel.signalEvents) { event in
                Button { viewModel.focusSignal(candleIndex: event.candleIndex) } label: {
                    HStack(spacing: AppSpacing.md) {
                        numberBadge(event.id)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(IndicatorCopy.signalLabel(event.kind)).font(AppFont.bodyStrong).foregroundStyle(AppColor.ink)
                            Text(IndicatorCopy.directionLabel(event.direction))
                                .font(AppFont.metaCaption).foregroundStyle(IndicatorCopy.directionColor(event.direction))
                        }
                        Spacer()
                    }
                    .padding(AppSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColor.backgroundPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.chip))
                }
                .buttonStyle(.plain)
            }
            Text("신호가 항상 맞는 건 아니에요. ‘당시엔 이런 흐름이 있었다’는 참고로 봐 주세요.")
                .font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted2).lineSpacing(2)
        }
    }

    private func numberBadge(_ n: Int) -> some View {
        Text("\(n)").font(AppFont.number(12)).foregroundStyle(.white)
            .frame(width: 22, height: 22).background(AppColor.accent).clipShape(Circle())
    }
}

// MARK: - 신호 상세 카드
private struct SignalDetailCard: View {
    let detail: ChartLearningViewModel.SignalDetail

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Text("\(detail.number)").font(AppFont.number(12)).foregroundStyle(.white)
                    .frame(width: 22, height: 22).background(AppColor.accent).clipShape(Circle())
                Text(detail.kindLabel).font(AppFont.newsTitle).foregroundStyle(AppColor.ink)
                Text(detail.daysAgo <= 1 ? "최근" : "\(detail.daysAgo)일 전")
                    .font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted2)
            }

            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Text("이 신호").font(AppFont.microCaption).foregroundStyle(AppColor.accentDeep)
                    .padding(.horizontal, AppSpacing.sm).padding(.vertical, 3)
                    .background(AppColor.accentTint).clipShape(RoundedRectangle(cornerRadius: AppRadius.badge))
                Text(detail.description).font(AppFont.bodyStrong).foregroundStyle(AppColor.inkSoft).lineSpacing(3)
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Text("그 이후 7거래일").font(AppFont.metaCaption).foregroundStyle(AppColor.inkSoft)
                    Spacer()
                    Text(detail.percentText).font(AppFont.number(14)).foregroundStyle(IndicatorCopy.directionColor(detail.direction))
                }
                HStack(spacing: AppSpacing.sm) {
                    Text("\(Formatters.grouped(detail.beforePrice))원").font(AppFont.number(13)).foregroundStyle(AppColor.textMuted)
                    Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold)).foregroundStyle(IndicatorCopy.directionColor(detail.direction))
                    Text("\(Formatters.grouped(detail.afterPrice))원").font(AppFont.number(13)).foregroundStyle(IndicatorCopy.directionColor(detail.direction))
                }
                Text(detail.afterText).font(AppFont.bodyStrong).foregroundStyle(AppColor.inkSoft).lineSpacing(2)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.backgroundPrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.row))

            Text("신호가 항상 맞는 건 아니에요. ‘당시엔 이런 흐름이 있었다’는 참고로 봐 주세요.")
                .font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted2).lineSpacing(2)
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.hairline, lineWidth: 1))
    }
}
