import SwiftUI

/// 모의 매수/매도 시트. 입력 → (매수)완료 닫힘 / (매도)직후 회고 스트리밍. 커밋 4 BottomSheet 위.
struct TradeSheetView: View {
    @Bindable var viewModel: TradeViewModel
    let onClose: () -> Void

    /// 매수/매도 강조색(한국 관례: 매수 빨강, 매도 파랑).
    private var accent: Color { viewModel.type == .buy ? AppColor.priceUp : AppColor.priceDown }

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(AppColor.controlBorder).frame(width: 38, height: 5)
                .padding(.top, AppSpacing.sm).padding(.bottom, AppSpacing.md)

            switch viewModel.phase {
            case .input, .submitting:
                inputForm
            case .completedBuy:
                Color.clear.frame(height: 1)
            case .retrospective:
                RetrospectiveCard(viewModel: viewModel, onClose: onClose)
            }
        }
        .containerRelativeFrame(.vertical) { height, _ in height * (viewModel.phase == .retrospective ? 0.82 : 0.7) }
        .task { await viewModel.load() }
        .onChange(of: viewModel.phase) { _, phase in
            if phase == .completedBuy { onClose() }
        }
        .onDisappear { viewModel.cancelRetrospective() }
    }

    // MARK: 입력 폼
    private var inputForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                HStack {
                    Text(viewModel.title).font(AppFont.focusCardTitle).foregroundStyle(AppColor.ink)
                    Spacer()
                    closeButton
                }

                if viewModel.type == .buy {
                    HStack(spacing: AppSpacing.xs) {
                        Text("매수 가능 금액").font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted2)
                        Text("\(Formatters.grouped(viewModel.buyingPower.amount))원").font(AppFont.number(13)).foregroundStyle(AppColor.accentDeep)
                        Spacer()
                    }
                }

                quantitySection
                amountRow

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("왜 \(viewModel.type == .buy ? "사" : "팔")나요? 근거를 적어 두면 나중에 회고에 도움이 돼요")
                        .font(AppFont.bodyStrong).foregroundStyle(AppColor.textMuted)
                    FlowLayout {
                        ForEach(viewModel.presets, id: \.self) { preset in
                            Button { viewModel.pickPreset(preset) } label: {
                                Pill(preset, style: viewModel.rationaleText == preset ? .accentSelected : .accentSoft)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    rationaleField
                }

                if let error = viewModel.errorMessage {
                    Text(error).font(AppFont.bodyStrong).foregroundStyle(accent)
                }

                executeButton
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.bottom, AppSpacing.xxl)
        }
    }

    private var quantitySection: some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                stepperButton(systemName: "minus") { viewModel.setQuantity(viewModel.quantity - 1) }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(viewModel.quantity)").font(AppFont.numberHero).foregroundStyle(AppColor.ink)
                    Text("주").font(AppFont.listItem).foregroundStyle(AppColor.textMuted)
                }
                Spacer()
                stepperButton(systemName: "plus") { viewModel.setQuantity(viewModel.quantity + 1) }
            }
            HStack(spacing: AppSpacing.sm) {
                ForEach([5, 10, 20], id: \.self) { preset in
                    Button { viewModel.setQuantity(preset) } label: {
                        Text("\(preset)주").font(AppFont.bodyStrong)
                            .foregroundStyle(viewModel.quantity == preset ? .white : AppColor.inkSoft)
                            .frame(maxWidth: .infinity).padding(.vertical, AppSpacing.sm)
                            .background(viewModel.quantity == preset ? accent : AppColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.chip))
                            .overlay(RoundedRectangle(cornerRadius: AppRadius.chip).stroke(viewModel.quantity == preset ? .clear : AppColor.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text(viewModel.type == .buy ? "최대 \(viewModel.maxQuantity)주" : "보유 \(viewModel.maxQuantity)주")
                    .font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted2)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColor.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
    }

    private var amountRow: some View {
        HStack {
            Text("\(Formatters.grouped(viewModel.price.amount))원 · \(viewModel.quantity)주").font(AppFont.bodyStrong).foregroundStyle(AppColor.textMuted)
            Spacer()
            Text("\(Formatters.grouped(viewModel.totalAmount.amount))원").font(AppFont.numberLarge).foregroundStyle(AppColor.ink)
        }
    }

    private var rationaleField: some View {
        VStack(alignment: .trailing, spacing: AppSpacing.xs) {
            TextField("직접 적어도 좋아요", text: $viewModel.rationaleText, axis: .vertical)
                .font(AppFont.newsTitle).foregroundStyle(AppColor.ink)
                .lineLimit(2...4)
                .padding(AppSpacing.md)
                .background(AppColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.row))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.row).stroke(AppColor.controlBorder, lineWidth: 1.5))
            Text("\(viewModel.rationaleText.count)/\(viewModel.maxRationaleLength)")
                .font(AppFont.microCaption).foregroundStyle(AppColor.textMuted2)
        }
    }

    private var executeButton: some View {
        Button { Task { await viewModel.execute() } } label: {
            Text(viewModel.canExecute ? "\(viewModel.quantity)주 \(viewModel.type == .buy ? "매수하기" : "매도하기")" : "근거를 적어 주세요")
                .font(AppFont.ctaLabel).foregroundStyle(viewModel.canExecute ? .white : AppColor.ctaDisabledForeground)
                .frame(maxWidth: .infinity).frame(height: 56)
                .background(viewModel.canExecute ? accent : AppColor.ctaDisabledBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canExecute || viewModel.phase == .submitting)
    }

    private func stepperButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName).font(.system(size: 15, weight: .bold)).foregroundStyle(AppColor.inkSoft)
                .frame(width: 40, height: 40).background(AppColor.surface).clipShape(Circle())
                .overlay(Circle().stroke(AppColor.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(AppColor.textMuted)
                .frame(width: 32, height: 32).background(AppColor.surfaceChip).clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 매도 직후 회고 카드(스트리밍)
private struct RetrospectiveCard: View {
    @Bindable var viewModel: TradeViewModel
    let onClose: () -> Void

    private var profit: Int { viewModel.realizedProfit.amount }
    private var profitColor: Color { profit >= 0 ? AppColor.priceUp : AppColor.priceDown }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                HStack {
                    Text("매도 회고").font(AppFont.focusCardTitle).foregroundStyle(AppColor.ink)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(AppColor.textMuted)
                            .frame(width: 32, height: 32).background(AppColor.surfaceChip).clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                if let retro = viewModel.retro {
                    Text(retro.summaryLine).font(AppFont.listItem).foregroundStyle(AppColor.ink)
                    HStack(alignment: .firstTextBaseline) {
                        Text("실현 손익").font(AppFont.bodyStrong).foregroundStyle(AppColor.textMuted)
                        Spacer()
                        Text("\(profit >= 0 ? "+" : "")\(Formatters.grouped(profit))원")
                            .font(AppFont.numberLarge).foregroundStyle(profitColor)
                    }
                    if retro.isPartialSell {
                        Text("일부만 매도했어요. 남은 수량은 계속 보유 중이라, 같은 방식으로 회고가 쌓여요.")
                            .font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted)
                            .padding(AppSpacing.md).frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColor.backgroundPrimary).clipShape(RoundedRectangle(cornerRadius: AppRadius.chip))
                    }

                    if !retro.goodPoints.isEmpty {
                        pointSection("잘한 부분", retro.goodPoints, dot: AppColor.correct)
                    }
                    if !retro.watchPoints.isEmpty {
                        pointSection("함께 살펴볼 부분", retro.watchPoints, dot: AppColor.indicatorMA)
                    }
                }

                if viewModel.retroState == .streaming {
                    HStack(spacing: AppSpacing.sm) {
                        ProgressView().tint(AppColor.accent)
                        Text("회고를 정리하고 있어요…").font(AppFont.bodyStrong).foregroundStyle(AppColor.textMuted)
                    }
                } else if case let .error(message) = viewModel.retroState {
                    Text(message).font(AppFont.bodyStrong).foregroundStyle(AppColor.textMuted)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.bottom, AppSpacing.xxl)
        }
    }

    private func pointSection(_ title: String, _ points: [String], dot: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title).font(AppFont.bodyStrong).foregroundStyle(AppColor.ink)
            ForEach(points, id: \.self) { point in
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Circle().fill(dot).frame(width: 6, height: 6).padding(.top, 6)
                    Text(point).font(AppFont.bodyStrong).foregroundStyle(AppColor.inkSoft).lineSpacing(3)
                }
            }
        }
        .padding(AppSpacing.md).frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.backgroundPrimary).clipShape(RoundedRectangle(cornerRadius: AppRadius.row))
    }
}
