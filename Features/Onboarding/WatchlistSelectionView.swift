import SwiftUI

/// 관심종목 선택 화면. 핸드오프: 고정 헤더(타이틀+n/5 카운트 필+검색) → 스크롤(검색결과 / 선택칩+인기) → 하단 CTA.
/// 5개 하드 캡(User.maxWatchlistCount), CTA는 최소 1개 선택 시 활성.
struct WatchlistSelectionView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onComplete: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColor.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
                    LazyVStack(spacing: AppSpacing.sm) {
                        content
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, AppSpacing.xs)
                    .padding(.bottom, 110) // CTA 영역 회피
                }
            }

            if let toast = viewModel.toastMessage {
                ToastView(message: toast)
                    .padding(.bottom, 96)
                    .transition(.opacity)
            }

            cta
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.toastMessage)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.loadPopular() }
        .onChange(of: viewModel.query) { Task { await viewModel.search() } }
    }

    // MARK: 헤더
    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top) {
                Text("관심 종목,\n딱 골라볼까요?")
                    .font(AppFont.screenTitle)
                    .foregroundStyle(AppColor.ink)
                    .lineSpacing(4)
                Spacer()
                Pill("\(viewModel.selectionCount)/\(viewModel.maxCount)",
                     style: viewModel.selectionCount > 0 ? .accentSelected : .neutralOutline)
                    .padding(.top, AppSpacing.xs)
            }
            Text("최소 1개부터 최대 \(viewModel.maxCount)개까지 담을 수 있어요")
                .font(AppFont.body)
                .foregroundStyle(AppColor.textMuted)
            SearchField(query: $viewModel.query, isActive: viewModel.isSearchActive, onClear: viewModel.clearSearch)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, AppSpacing.xxl)
        .padding(.bottom, AppSpacing.md)
    }

    // MARK: 콘텐츠
    @ViewBuilder
    private var content: some View {
        if viewModel.isSearchActive {
            if viewModel.showsNoResults {
                NoResultsView()
            } else {
                ForEach(viewModel.searchResults) { stock in
                    row(for: stock)
                }
            }
        } else {
            if !viewModel.selectedStocks.isEmpty {
                selectedChips
            }
            sectionHeader
            ForEach(viewModel.popular) { stock in
                row(for: stock)
            }
        }
    }

    private func row(for stock: Stock) -> some View {
        StockRowView(
            stock: stock,
            quote: viewModel.quote(for: stock.code),
            isSelected: viewModel.isSelected(stock.code),
            onToggle: { viewModel.toggle(stock.code) }
        )
    }

    private var selectedChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(viewModel.selectedStocks) { stock in
                    WatchlistChip(name: stock.name) { viewModel.toggle(stock.code) }
                }
            }
            .padding(.vertical, AppSpacing.xs)
        }
    }

    private var sectionHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
            Text("인기 종목")
                .font(AppFont.sectionHeader)
                .foregroundStyle(AppColor.ink)
            Text("초보자들이 많이 담아요")
                .font(AppFont.metaCaption)
                .foregroundStyle(AppColor.textMuted2)
            Spacer()
        }
        .padding(.vertical, AppSpacing.xs)
    }

    // MARK: CTA
    private var cta: some View {
        PrimaryButton(
            viewModel.canProceed ? "\(viewModel.selectionCount)개 담고 시작하기" : "관심종목을 골라주세요",
            state: viewModel.isSaving ? .loading : (viewModel.canProceed ? .enabled : .disabled)
        ) {
            Task { if await viewModel.saveWatchlist() { onComplete() } }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.bottom, AppSpacing.xxl)
        .padding(.top, AppSpacing.md)
        .background(
            LinearGradient(
                colors: [AppColor.backgroundPrimary, AppColor.backgroundPrimary.opacity(0)],
                startPoint: .bottom, endPoint: .top
            )
            .ignoresSafeArea()
        )
    }
}

// MARK: - 하위 뷰

/// 검색 입력 필드.
private struct SearchField: View {
    @Binding var query: String
    let isActive: Bool
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColor.textMuted2)
            TextField("종목명 또는 종목코드 검색", text: $query)
                .font(AppFont.listItem)
                .foregroundStyle(AppColor.ink)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if isActive {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColor.textMuted2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(height: 50)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColor.controlBorder, lineWidth: 1.5)
        )
    }
}

/// 선택 종목 칩(× 제거).
private struct WatchlistChip: View {
    let name: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Text(name)
                .font(AppFont.bodyStrong)
                .foregroundStyle(AppColor.accentDeep)
                .lineLimit(1)
            Button(action: onRemove) {
                ZStack {
                    Circle().fill(AppColor.accent)
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, AppSpacing.md)
        .padding(.trailing, AppSpacing.sm)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColor.accentTint)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppColor.accentTintBorder, lineWidth: 1))
    }
}

/// 검색 결과 없음.
private struct NoResultsView: View {
    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            Text("검색 결과가 없어요")
                .font(AppFont.listItem)
                .foregroundStyle(AppColor.textMuted)
            Text("종목명이나 6자리 코드를 다시 확인해 주세요")
                .font(AppFont.bodyStrong)
                .foregroundStyle(AppColor.textMuted2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxl * 2)
    }
}

/// 토스트(다크 pill).
private struct ToastView: View {
    let message: String
    var body: some View {
        Pill(message, style: .dark)
    }
}
