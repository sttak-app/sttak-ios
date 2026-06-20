import SwiftUI

/// 퀴즈 탭. 자본금 배너 + (진행 → 채점/해설 → 결과 → 쿨다운).
struct QuizView: View {
    @Environment(\.container) private var container
    @State private var viewModel: QuizViewModel?

    var onGoToChart: () -> Void = {}
    var onGoToRanking: () -> Void = {}

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
                viewModel = container.makeQuizViewModel()
                await viewModel?.load()
            }
        }
        .onDisappear { viewModel?.stopTicking() }
    }

    @ViewBuilder
    private func content(_ viewModel: QuizViewModel) -> some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                CapitalBanner(capital: viewModel.currentCapital)

                #if DEBUG
                Button("DEBUG: 쿨다운 초기화") { Task { await viewModel.debugResetCooldown() } }
                    .font(AppFont.metaCaption).foregroundStyle(AppColor.accentDeep)
                    .frame(maxWidth: .infinity, alignment: .leading)
                #endif

                switch viewModel.phase {
                case .loading:
                    ProgressView().tint(AppColor.accent).padding(.top, AppSpacing.xxl)
                case .playing:
                    PlayingView(viewModel: viewModel)
                case .done:
                    DoneView(viewModel: viewModel, onGoToChart: onGoToChart, onGoToRanking: onGoToRanking)
                case .cooldown:
                    CooldownView(viewModel: viewModel, onGoToChart: onGoToChart, onGoToRanking: onGoToRanking)
                case let .failed(message):
                    VStack(spacing: AppSpacing.md) {
                        Text(message).font(AppFont.body).foregroundStyle(AppColor.textMuted)
                        Button("다시 시도") { Task { await viewModel.load() } }
                            .font(AppFont.ctaLabel).foregroundStyle(AppColor.accentDeep)
                    }.padding(.top, AppSpacing.xxl)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.xxl)
        }
    }
}

// MARK: - 자본금 배너
private struct CapitalBanner: View {
    let capital: Int
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("내 모의투자 자본금").font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted2)
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                    Text(Formatters.grouped(capital)).font(AppFont.numberLarge).foregroundStyle(.white)
                    Text("원").font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted2)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "shield.fill").font(.system(size: 10)).foregroundStyle(AppColor.accentBright)
                    Text("정답 1문제 +50만").font(AppFont.number(12)).foregroundStyle(AppColor.accentBright)
                }
                .padding(.horizontal, AppSpacing.sm).padding(.vertical, AppSpacing.xs)
                .background(AppColor.accent.opacity(0.18)).clipShape(Capsule())
                Text("맞힌 만큼 투자 자본금으로 쌓여요").font(AppFont.microCaption).foregroundStyle(AppColor.textMuted)
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(AppColor.ink)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.banner))
    }
}

// MARK: - 진행
private struct PlayingView: View {
    @Bindable var viewModel: QuizViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Text("오늘의 3문제").font(AppFont.bodyStrong).foregroundStyle(AppColor.inkSoft)
                Text(viewModel.progressNumberText).font(AppFont.number(12)).foregroundStyle(AppColor.textMuted2)
                Spacer()
                HStack(spacing: AppSpacing.xs) {
                    ForEach(0..<viewModel.totalCount, id: \.self) { i in
                        Circle()
                            .fill(i < viewModel.currentIndex ? AppColor.accent : (i == viewModel.currentIndex ? AppColor.accentTintBorder : AppColor.controlBorder))
                            .frame(width: 8, height: 8)
                    }
                }
            }

            if let question = viewModel.currentQuestion {
                questionCard(question)
                if viewModel.isRevealed { explanation(question) }
            }

            PrimaryButton(viewModel.primaryButtonLabel, state: viewModel.primaryButtonEnabled ? .enabled : .disabled) {
                Task { await viewModel.primaryAction() }
            }
        }
    }

    private func questionCard(_ question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack(spacing: AppSpacing.xs) {
                Circle().fill(categoryColor(question.category)).frame(width: 6, height: 6)
                Text(question.category).font(AppFont.badge).foregroundStyle(categoryColor(question.category))
            }
            .padding(.horizontal, AppSpacing.md).padding(.vertical, AppSpacing.xs)
            .background(categoryColor(question.category).opacity(0.12)).clipShape(Capsule())

            Text(question.question)
                .font(AppFont.quizQuestion).foregroundStyle(AppColor.ink).lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: AppSpacing.sm) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                    optionRow(question: question, index: index, option: option)
                }
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.banner))
        .appShadow(AppShadow.card)
    }

    private func optionRow(question: QuizQuestion, index: Int, option: String) -> some View {
        let state = optionState(question: question, index: index)
        return Button { viewModel.selectOption(index) } label: {
            HStack(spacing: AppSpacing.md) {
                Text(["A", "B", "C", "D"][index])
                    .font(AppFont.number(12)).foregroundStyle(state.keyForeground)
                    .frame(width: 25, height: 25).background(state.keyBackground).clipShape(Circle())
                    .overlay(Circle().stroke(state.keyBorder, lineWidth: 1.5))
                Text(option).font(AppFont.newsTitle).foregroundStyle(state.textColor)
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: AppSpacing.xs)
                if let mark = state.mark {
                    Image(systemName: mark).font(.system(size: 13, weight: .bold)).foregroundStyle(state.markColor)
                }
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(state.background)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.row))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.row).stroke(state.border, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isRevealed)
    }

    private func explanation(_ question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Text(viewModel.wasCurrentCorrect ? "정답" : "오답")
                    .font(AppFont.badge).foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.sm).padding(.vertical, 3)
                    .background(viewModel.wasCurrentCorrect ? AppColor.correct : AppColor.wrong)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.badge))
                if viewModel.wasCurrentCorrect {
                    Text("+\(Formatters.grouped(QuizReward.capitalPerCorrect))원 자본금")
                        .font(AppFont.number(13)).foregroundStyle(AppColor.correct)
                }
            }
            Text(question.explanation).font(AppFont.bodyStrong).foregroundStyle(AppColor.inkSoft).lineSpacing(3)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(viewModel.wasCurrentCorrect ? AppColor.correctTint : AppColor.wrongTint)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
    }

    // 옵션 상태(선택/채점)
    private struct OptionStyle {
        var background: Color; var border: Color
        var keyBackground: Color; var keyBorder: Color; var keyForeground: Color
        var textColor: Color; var mark: String?; var markColor: Color
    }

    private func optionState(question: QuizQuestion, index: Int) -> OptionStyle {
        let isSelected = viewModel.selectedOption == index
        if viewModel.isRevealed {
            if index == question.answerIndex {
                return OptionStyle(background: AppColor.correctTint, border: AppColor.correct,
                                   keyBackground: AppColor.correct, keyBorder: .clear, keyForeground: .white,
                                   textColor: AppColor.ink, mark: "checkmark", markColor: AppColor.correct)
            } else if isSelected {
                return OptionStyle(background: AppColor.wrongTint, border: AppColor.wrong,
                                   keyBackground: AppColor.wrong, keyBorder: .clear, keyForeground: .white,
                                   textColor: AppColor.ink, mark: "xmark", markColor: AppColor.wrong)
            }
            return OptionStyle(background: AppColor.surface, border: AppColor.hairline,
                               keyBackground: AppColor.surface, keyBorder: AppColor.controlBorder, keyForeground: AppColor.textMuted2,
                               textColor: AppColor.textMuted, mark: nil, markColor: .clear)
        }
        if isSelected {
            return OptionStyle(background: AppColor.accentTint, border: AppColor.accentTintBorder,
                               keyBackground: AppColor.accent, keyBorder: .clear, keyForeground: .white,
                               textColor: AppColor.ink, mark: nil, markColor: .clear)
        }
        return OptionStyle(background: AppColor.surface, border: AppColor.hairline,
                           keyBackground: AppColor.surface, keyBorder: AppColor.controlBorder, keyForeground: AppColor.inkSoft,
                           textColor: AppColor.ink, mark: nil, markColor: .clear)
    }

    private func categoryColor(_ category: String) -> Color {
        if category.contains("차트") || category.contains("지표") { return AppColor.indicatorMA }
        if category.contains("가치") { return AppColor.priceDown }
        return AppColor.accent
    }
}

// MARK: - 결과
private struct DoneView: View {
    @Bindable var viewModel: QuizViewModel
    let onGoToChart: () -> Void
    let onGoToRanking: () -> Void

    private var correct: Int { viewModel.outcome?.correctCount ?? 0 }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .bold)).foregroundStyle(resultColor)
                    .frame(width: 66, height: 66).background(resultColor.opacity(0.14)).clipShape(Circle())
                Text(resultTitle).font(AppFont.resultTitle).foregroundStyle(AppColor.ink)
                Text("3문제 중 \(correct)문제를 맞혔어요").font(AppFont.body).foregroundStyle(AppColor.textMuted)
            }
            .padding(.top, AppSpacing.lg)

            earnedCard
            recapCard

            PrimaryButton("쌓은 자본금으로 투자 연습하기", action: onGoToChart)
            Button(action: onGoToRanking) {
                Text("내 랭킹 확인하기").font(AppFont.newsTitle).foregroundStyle(AppColor.inkSoft)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(AppColor.surface).clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                    .appShadow(AppShadow.card)
            }
            .buttonStyle(.plain)

            if let next = viewModel.nextAvailableAt {
                Text("다음 3문제까지 \(Formatters.countdown(from: viewModel.now, to: next))")
                    .font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted2)
            }
        }
    }

    private var earnedCard: some View {
        VStack(spacing: AppSpacing.md) {
            Text("이번에 쌓은 모의투자 자본금").font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted2)
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text("+\(Formatters.grouped(viewModel.outcome?.earnedCapital.amount ?? 0))")
                    .font(AppFont.numberHero).foregroundStyle(AppColor.accentBright)
                Text("원").font(AppFont.listItem).foregroundStyle(AppColor.textMuted2)
            }
            Rectangle().fill(.white.opacity(0.09)).frame(height: 1)
            HStack(spacing: AppSpacing.sm) {
                Text("총 자본금").font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted2)
                Text("\(Formatters.grouped(viewModel.currentCapital))원").font(AppFont.number(16)).foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(AppColor.ink)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.banner))
    }

    private var recapCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.recap.enumerated()), id: \.offset) { i, item in
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: item.isCorrect ? "checkmark" : "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(item.isCorrect ? AppColor.correct : AppColor.wrong)
                        .frame(width: 22, height: 22)
                        .background((item.isCorrect ? AppColor.correct : AppColor.wrong).opacity(0.14)).clipShape(Circle())
                    Text(item.title).font(AppFont.bodyStrong).foregroundStyle(AppColor.inkSoft).lineLimit(2)
                    Spacer()
                }
                .padding(.vertical, AppSpacing.md)
                if i < viewModel.recap.count - 1 { Rectangle().fill(AppColor.hairline2).frame(height: 1) }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .appShadow(AppShadow.card)
    }

    private var resultTitle: String {
        switch correct {
        case 3: return "완벽해요!"
        case 2: return "잘했어요!"
        case 1: return "좋아요, 시작이에요"
        default: return "다음엔 더 잘할 수 있어요"
        }
    }
    private var resultColor: Color { correct >= 2 ? AppColor.correct : AppColor.accent }
}

// MARK: - 쿨다운
private struct CooldownView: View {
    @Bindable var viewModel: QuizViewModel
    let onGoToChart: () -> Void
    let onGoToRanking: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "clock")
                    .font(.system(size: 26)).foregroundStyle(AppColor.textMuted)
                    .frame(width: 64, height: 64).background(AppColor.surfaceAlt).clipShape(Circle())
                Text("오늘 분량을 모두 풀었어요").font(AppFont.focusCardTitle).foregroundStyle(AppColor.ink)
                Text("퀴즈는 6시간마다 새로운 3문제가 열려요.\n잠시 뒤 다시 도전해 보세요.")
                    .font(AppFont.bodyStrong).foregroundStyle(AppColor.textMuted).multilineTextAlignment(.center).lineSpacing(3)
            }
            .padding(.top, AppSpacing.lg)

            VStack(spacing: AppSpacing.md) {
                Text("다음 세트까지").font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted2)
                if let next = viewModel.nextAvailableAt {
                    Text(Formatters.countdown(from: viewModel.now, to: next))
                        .font(AppFont.numberHero).foregroundStyle(AppColor.ink)
                    progressBar(next: next)
                }
                if let last = viewModel.lastCompletion {
                    Text("지난 세트 \(last.correctCount) 정답 · 자본금 +\(Formatters.grouped(last.earnedCapital.amount))원")
                        .font(AppFont.microCaption).foregroundStyle(AppColor.textMuted2)
                }
            }
            .padding(AppSpacing.xl)
            .frame(maxWidth: .infinity)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.banner))
            .appShadow(AppShadow.card)

            PrimaryButton("투자 연습하러 가기", action: onGoToChart)
            Button(action: onGoToRanking) {
                Text("내 랭킹 확인하기").font(AppFont.newsTitle).foregroundStyle(AppColor.inkSoft)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(AppColor.surface).clipShape(RoundedRectangle(cornerRadius: AppRadius.card)).appShadow(AppShadow.card)
            }
            .buttonStyle(.plain)
        }
    }

    private func progressBar(next: Date) -> some View {
        let remaining = max(0, next.timeIntervalSince(viewModel.now))
        let progress = max(0, min(1, (QuizReward.cooldown - remaining) / QuizReward.cooldown))
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(AppColor.surfaceAlt)
                Capsule().fill(AppColor.accent).frame(width: geo.size.width * progress)
            }
        }
        .frame(height: 6)
    }
}
