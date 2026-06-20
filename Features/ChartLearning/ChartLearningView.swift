import SwiftUI

/// 차트학습 화면. 종목 선택 + 캔들차트(기간/줌/팬). ⚠ Swift Charts를 직접 import하지 않고
/// ChartRenderer protocol에만 의존한다(확정 E10).
struct ChartLearningView: View {
    @Environment(\.container) private var container
    @State private var viewModel: ChartLearningViewModel?

    /// 기본 렌더러(Swift Charts). 추후 Canvas 렌더러로 교체 가능.
    private let renderer: ChartRenderer = SwiftChartsRenderer()

    @State private var panBaseStart: Int?
    @State private var zoomBaseCount: Int?

    var body: some View {
        ZStack {
            AppColor.backgroundPrimary.ignoresSafeArea()
            if let viewModel {
                content(viewModel)
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
    }

    @ViewBuilder
    private func content(_ viewModel: ChartLearningViewModel) -> some View {
        VStack(spacing: 0) {
            header(viewModel)
            if viewModel.stocks.count > 1 {
                stockSelector(viewModel)
            }
            chartArea(viewModel)
                .padding(.top, AppSpacing.md)
            periodSelector(viewModel)
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.lg)
            Spacer()
        }
    }

    // MARK: 헤더 (종목명 + 현재가)
    @ViewBuilder
    private func header(_ viewModel: ChartLearningViewModel) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(viewModel.selectedStock?.name ?? "차트학습")
                .font(AppFont.screenTitle)
                .foregroundStyle(AppColor.ink)
            Spacer()
            if let quote = viewModel.quote {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                    Text(Formatters.grouped(quote.price.amount))
                        .font(AppFont.numberLarge)
                        .foregroundStyle(AppColor.ink)
                    Text(Formatters.signedPercent(quote.changePercent))
                        .font(AppFont.number(14))
                        .foregroundStyle(quote.changePercent >= 0 ? AppColor.priceUp : AppColor.priceDown)
                }
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
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
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.chip)
                                    .stroke(selected ? .clear : AppColor.hairline, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
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
                    renderer.candleChart(viewModel.visibleCandles)
                        .gesture(panGesture(viewModel, width: geo.size.width))
                        .simultaneousGesture(zoomGesture(viewModel))
                }
            }
            .frame(width: geo.size.width, height: 236)
        }
        .frame(height: 236)
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }

    // MARK: 기간 선택
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

    // MARK: 제스처 (팬·줌 — Charts 비의존, ViewModel 윈도잉)
    private func panGesture(_ viewModel: ChartLearningViewModel, width: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if panBaseStart == nil { panBaseStart = viewModel.viewport.start }
                let candleWidth = width / CGFloat(max(viewModel.viewport.count, 1))
                let deltaCandles = Int((-value.translation.width / max(candleWidth, 1)).rounded())
                viewModel.scroll(toStart: (panBaseStart ?? 0) + deltaCandles)
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
