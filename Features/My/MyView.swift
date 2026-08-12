import SwiftUI

/// 마이 탭. 총 평가 자산/수익률 · 보유 종목 · 랭킹 진입(스텁) · 매매기록 · AI 회고 아코디언.
struct MyView: View {
    @Environment(\.container) private var container
    @State private var viewModel: MyViewModel?
    var onSignedOut: () -> Void = {}

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.backgroundPrimary.ignoresSafeArea()
                if let viewModel {
                    content(viewModel)
                } else {
                    ProgressView().tint(AppColor.accent)
                }
            }
            .navigationTitle("마이")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(onSignedOut: onSignedOut)
                    } label: {
                        Image(systemName: "gearshape").foregroundStyle(AppColor.inkSoft)
                    }
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = container.makeMyViewModel()
            }
            await viewModel?.load()  // 탭 재진입마다 갱신(트레이드/퀴즈 반영)
        }
    }

    @ViewBuilder
    private func content(_ viewModel: MyViewModel) -> some View {
        switch viewModel.phase {
        case .loading:
            ProgressView().tint(AppColor.accent)
        case let .failed(message):
            VStack(spacing: AppSpacing.md) {
                Text(message).font(AppFont.body).foregroundStyle(AppColor.textMuted)
                Button("다시 시도") { Task { await viewModel.load() } }
                    .font(AppFont.ctaLabel).foregroundStyle(AppColor.accentDeep)
            }
        case .loaded:
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    if let valuation = viewModel.valuation {
                        AssetHero(valuation: valuation)
                        HoldingsSection(positions: valuation.positions)
                    }
                    RankingEntryCard()
                    TradeHistorySection(viewModel: viewModel)
                    RetroSection(viewModel: viewModel)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.lg)
            }
        }
    }
}

// MARK: 공통 헬퍼
private func pnlColor(_ amount: Int) -> Color { amount >= 0 ? AppColor.priceUp : AppColor.priceDown }
private func signed(_ amount: Int) -> String { (amount >= 0 ? "+" : "") + Formatters.grouped(amount) }

/// 매도 실현손익률(%) = 실현손익 / 원가(체결가×수량 − 실현손익) × 100. 체결된 매도에서만.
private func returnPercent(of trade: Trade) -> Double? {
    guard trade.status == .filled,
          let profit = trade.realizedProfit?.amount,
          let fill = trade.filledPrice?.amount else { return nil }
    let costBasis = fill * trade.quantity - profit
    return costBasis != 0 ? Double(profit) / Double(costBasis) * 100 : nil
}

// MARK: - 자산 히어로
private struct AssetHero: View {
    let valuation: PortfolioValuation
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("총 평가 자산").font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted2)
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text(Formatters.grouped(valuation.totalAssets.amount)).font(AppFont.numberHero).foregroundStyle(.white)
                Text("원").font(AppFont.listItem).foregroundStyle(AppColor.textMuted2)
            }
            .padding(.top, AppSpacing.sm)
            HStack(spacing: AppSpacing.sm) {
                Text("\(signed(valuation.totalReturn.amount))원").font(AppFont.number(14))
                Text(Formatters.signedPercent(valuation.returnRate)).font(AppFont.number(13))
                Text("시작 자산 \(Formatters.grouped(EvaluatePortfolio.startingCapital))원 대비")
                    .font(AppFont.microCaption).foregroundStyle(AppColor.textMuted)
            }
            // 다크 자산 카드 전용 손익 톤(부호별). 보유·매매 손익은 priceUp/Down 유지.
            .foregroundStyle(valuation.totalReturn.amount >= 0 ? AppColor.assetPnLUp : AppColor.assetPnLDown)
            .padding(.top, AppSpacing.sm)

            Rectangle().fill(.white.opacity(0.09)).frame(height: 1).padding(.vertical, AppSpacing.md)

            HStack(spacing: 0) {
                heroStat("투자 가능 현금", valuation.cash.amount)
                Rectangle().fill(.white.opacity(0.09)).frame(width: 1, height: 34)
                heroStat("주식 평가 금액", valuation.stockValue.amount).padding(.leading, AppSpacing.lg)
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.ink)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.banner))
    }

    private func heroStat(_ title: String, _ amount: Int) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title).font(AppFont.microCaption).foregroundStyle(AppColor.textMuted2)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(Formatters.grouped(amount)).font(AppFont.number(16)).foregroundStyle(.white.opacity(0.9))
                Text(" 원").font(AppFont.microCaption).foregroundStyle(AppColor.textMuted2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 보유 종목
private struct HoldingsSection: View {
    let positions: [PositionValuation]
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("보유 종목", count: positions.count)
            if positions.isEmpty {
                Text("아직 보유 중인 종목이 없어요. 차트학습에서 모의 매수를 연습해 보세요.")
                    .font(AppFont.bodyStrong).foregroundStyle(AppColor.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.lg).background(AppColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card)).appShadow(AppShadow.card)
            } else {
                VStack(spacing: 0) {
                    ForEach(positions) { position in
                        row(position)
                        if position.id != positions.last?.id {
                            Rectangle().fill(AppColor.hairline2).frame(height: 1)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .background(AppColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card)).appShadow(AppShadow.card)
            }
        }
    }

    private func row(_ p: PositionValuation) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.xs) {
                    Text(p.stockName).font(AppFont.listItem).foregroundStyle(AppColor.ink)
                    Text("\(p.quantity)주").font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted2)
                }
                Text("평단 \(Formatters.grouped(p.averagePrice.amount))원 · 현재 \(Formatters.grouped(p.currentPrice.amount))원")
                    .font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                Text("\(Formatters.grouped(p.marketValue.amount))원").font(AppFont.number(14)).foregroundStyle(AppColor.ink)
                Text("\(signed(p.unrealizedPnL.amount)) · \(Formatters.signedPercent(p.returnRate, fractionDigits: 1))")
                    .font(AppFont.number(12)).foregroundStyle(pnlColor(p.unrealizedPnL.amount))
            }
        }
        .padding(.vertical, AppSpacing.md)
    }
}

// MARK: - 랭킹 진입(스텁)
private struct RankingEntryCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("랭킹 현황", count: nil)
            NavigationLink {
                RankingView()
            } label: {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "trophy.fill").font(.system(size: 18)).foregroundStyle(AppColor.accent)
                        .frame(width: 46, height: 46).background(AppColor.accentTintSoft)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.chip))
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("보유 자산 랭킹").font(AppFont.listItem).foregroundStyle(AppColor.ink)
                        Text("다른 사용자와 내 순위를 비교해 보세요").font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted2)
                    }
                    Spacer()
                    HStack(spacing: 2) {
                        Text("전체 보기").font(AppFont.metaCaption).foregroundStyle(AppColor.accentDeep)
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(AppColor.accentDeep)
                    }
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: .infinity)
                .background(AppColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card)).appShadow(AppShadow.card)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 매매기록
private struct TradeHistorySection: View {
    @Bindable var viewModel: MyViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("매수 · 매도 기록").font(AppFont.sectionHeader).foregroundStyle(AppColor.ink)
            SegmentedControl(
                MyViewModel.TradeFilter.allCases.map(\.label),
                selection: Binding(
                    get: { MyViewModel.TradeFilter.allCases.firstIndex(of: viewModel.tradeFilter) ?? 0 },
                    set: { viewModel.setFilter(MyViewModel.TradeFilter.allCases[$0]) }
                )
            )
            ForEach(viewModel.filteredTrades) { trade in
                tradeCard(trade)
            }
        }
    }

    private func tradeCard(_ trade: Trade) -> some View {
        let isBuy = trade.type == .buy
        let isOpen = viewModel.openTradeIDs.contains(trade.id)
        // 체결 전(접수/거부/취소)은 참고가, 체결이면 체결가 표시.
        let priceAmount = (trade.filledPrice ?? trade.referencePrice)?.amount
        return VStack(alignment: .leading, spacing: 0) {
            Button { viewModel.toggleTrade(trade.id) } label: {
                HStack(spacing: AppSpacing.sm) {
                    Text(isBuy ? "매수" : "매도").font(AppFont.badge).foregroundStyle(isBuy ? AppColor.priceUp : AppColor.priceDown)
                        .padding(.horizontal, AppSpacing.sm).padding(.vertical, 3)
                        .background((isBuy ? AppColor.priceUp : AppColor.priceDown).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.badge))
                    statusChip(trade.status)
                    Text(viewModel.name(for: trade.stockCode)).font(AppFont.listItem).foregroundStyle(AppColor.ink)
                    if let priceAmount {
                        Text("\(trade.quantity)주 · \(Formatters.grouped(priceAmount))원").font(AppFont.number(13)).foregroundStyle(AppColor.inkSoft)
                    } else {
                        Text("\(trade.quantity)주").font(AppFont.number(13)).foregroundStyle(AppColor.inkSoft)
                    }
                    Spacer(minLength: AppSpacing.xs)
                    if let pct = returnPercent(of: trade) {
                        Text(Formatters.signedPercent(pct, fractionDigits: 1)).font(AppFont.number(13)).foregroundStyle(pnlColor(trade.realizedProfit?.amount ?? 0))
                    }
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold)).foregroundStyle(AppColor.textMuted2)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            if isOpen {
                statusDetail(trade).padding(.top, AppSpacing.md)
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Text("근거").font(AppFont.microCaption).foregroundStyle(AppColor.textMuted)
                        .padding(.horizontal, AppSpacing.xs).padding(.vertical, 2)
                        .background(AppColor.surfaceAlt).clipShape(RoundedRectangle(cornerRadius: AppRadius.badge))
                    Text(trade.rationale.text).font(AppFont.bodyStrong).foregroundStyle(AppColor.inkSoft).lineSpacing(2)
                }
                .padding(AppSpacing.md).frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.backgroundPrimary).clipShape(RoundedRectangle(cornerRadius: AppRadius.row))
                .padding(.top, AppSpacing.sm)

                if trade.status == .pending {
                    Button { Task { await viewModel.cancelOrder(trade.id) } } label: {
                        Text("주문 취소").font(AppFont.metaCaption).foregroundStyle(AppColor.priceDown)
                            .frame(maxWidth: .infinity).padding(.vertical, AppSpacing.sm)
                            .overlay(RoundedRectangle(cornerRadius: AppRadius.row).strokeBorder(AppColor.priceDown.opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, AppSpacing.sm)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card)).appShadow(AppShadow.card)
    }

    /// 상태별 펼침 내용(체결/접수/거부/취소).
    @ViewBuilder
    private func statusDetail(_ trade: Trade) -> some View {
        switch trade.status {
        case .filled:
            HStack {
                Text("체결 \(trade.filledAt.map(Formatters.koreanDate) ?? "-")").font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted2)
                Spacer()
                if let profit = trade.realizedProfit?.amount {
                    Text("\(signed(profit))원").font(AppFont.number(13)).foregroundStyle(pnlColor(profit))
                }
            }
        case .pending:
            HStack {
                Text("다음 영업일 체결 예정" + (trade.tradingDate.map { " · \(Formatters.koreanDate($0))" } ?? ""))
                    .font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted2)
                Spacer()
            }
        case .rejected:
            HStack(alignment: .top, spacing: AppSpacing.xs) {
                Text("거부 사유").font(AppFont.metaCaption).foregroundStyle(AppColor.priceDown)
                Text(trade.rejectedReason ?? "체결 조건을 충족하지 못했어요.").font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted)
                Spacer()
            }
        case .cancelled:
            Text("취소한 주문이에요.").font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted2)
        }
    }

    private func statusChip(_ status: TradeStatus) -> some View {
        let (label, color): (String, Color) = {
            switch status {
            case .pending: return ("접수", AppColor.accentDeep)
            case .filled: return ("체결", AppColor.textMuted2)
            case .rejected: return ("거부", AppColor.priceDown)
            case .cancelled: return ("취소", AppColor.textMuted2)
            }
        }()
        return Text(label).font(AppFont.microCaption).foregroundStyle(color)
            .padding(.horizontal, AppSpacing.xs).padding(.vertical, 2)
            .background(color.opacity(0.10)).clipShape(RoundedRectangle(cornerRadius: AppRadius.badge))
    }
}

// MARK: - AI 회고 아코디언 (커밋 15 회고 표시)
private struct RetroSection: View {
    @Bindable var viewModel: MyViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("AI 회고 기록").font(AppFont.sectionHeader).foregroundStyle(AppColor.ink)
            Text("매도 직후, 그때의 판단을 돌아본 기록이에요.").font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted2)
            ForEach(viewModel.retroTrades) { trade in
                if let retro = trade.retrospective {
                    retroCard(trade: trade, retro: retro)
                }
            }
        }
    }

    private func retroCard(trade: Trade, retro: Retrospective) -> some View {
        let isOpen = viewModel.openRetroIDs.contains(trade.id)
        return VStack(alignment: .leading, spacing: AppSpacing.md) {
            Button { viewModel.toggleRetro(trade.id) } label: {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "sparkles").font(.system(size: 12)).foregroundStyle(.white)
                            .frame(width: 26, height: 26).background(AppColor.accent).clipShape(RoundedRectangle(cornerRadius: AppRadius.badge))
                        Text("\(viewModel.name(for: trade.stockCode)) 회고").font(AppFont.listItem).foregroundStyle(AppColor.ink)
                        Spacer()
                        Text(Formatters.koreanDate(trade.filledAt ?? trade.orderedAt)).font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted2)
                        Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold)).foregroundStyle(AppColor.textMuted2)
                            .rotationEffect(.degrees(isOpen ? 180 : 0))
                    }
                    HStack(spacing: AppSpacing.sm) {
                        Text(retro.summaryLine).font(AppFont.bodyStrong).foregroundStyle(AppColor.inkSoft)
                        Spacer()
                        if let profit = trade.realizedProfit?.amount, let pct = returnPercent(of: trade) {
                            Text("\(signed(profit))원 · \(Formatters.signedPercent(pct, fractionDigits: 1))").font(AppFont.number(13)).foregroundStyle(pnlColor(profit))
                        }
                    }
                    .padding(AppSpacing.md).background(AppColor.backgroundPrimary).clipShape(RoundedRectangle(cornerRadius: AppRadius.row))
                }
            }
            .buttonStyle(.plain)

            if isOpen {
                pointBlock("잘한 부분", retro.goodPoints, color: AppColor.accentDeep, bullet: "checkmark")
                pointBlock("함께 살펴볼 부분", retro.watchPoints, color: AppColor.indicatorMA, bullet: "dot")
                // 한 달 뒤 후속 회고는 커밋 21+ (서버 스케줄러). 지금은 대기 안내만.
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "clock").font(.system(size: 13)).foregroundStyle(AppColor.textMuted)
                    Text("한 달 뒤 후속 회고가 도착하면 함께 보여드려요.").font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted)
                }
                .padding(AppSpacing.md).frame(maxWidth: .infinity, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: AppRadius.row).strokeBorder(AppColor.controlBorder, style: StrokeStyle(lineWidth: 1, dash: [4])))
            } else {
                HStack(spacing: AppSpacing.sm) {
                    Circle().fill(AppColor.textMuted2).frame(width: 6, height: 6)
                    Text("매도 직후 회고 · 한 달 뒤 후속 예정").font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted2)
                    Spacer()
                    Text("자세히 보기").font(AppFont.metaCaption).foregroundStyle(AppColor.accentDeep)
                }
                .padding(.top, AppSpacing.sm).overlay(alignment: .top) { Rectangle().fill(AppColor.hairline2).frame(height: 1) }
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.banner)).appShadow(AppShadow.card)
    }

    private func pointBlock(_ title: String, _ points: [String], color: Color, bullet: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title).font(AppFont.metaCaption).foregroundStyle(color)
            ForEach(points, id: \.self) { point in
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    if bullet == "checkmark" {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(AppColor.accent).padding(.top, 2)
                    } else {
                        Circle().fill(color).frame(width: 5, height: 5).padding(.top, 6)
                    }
                    Text(point).font(AppFont.bodyStrong).foregroundStyle(AppColor.inkSoft).lineSpacing(2)
                }
            }
        }
    }
}

// MARK: 공통
private func sectionHeader(_ title: String, count: Int?) -> some View {
    HStack(spacing: AppSpacing.xs) {
        Text(title).font(AppFont.sectionHeader).foregroundStyle(AppColor.ink)
        if let count { Text("\(count)").font(AppFont.number(13)).foregroundStyle(AppColor.textMuted2) }
    }
}
