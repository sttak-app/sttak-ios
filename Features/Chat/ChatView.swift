import SwiftUI

/// 공용 챗봇 시트(멀티턴). 홈의 "AI에게 묻기" 버튼 → BottomSheet로 표시.
struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    var onClose: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(AppColor.hairline)
            messageList
            inputArea
        }
        .frame(maxWidth: .infinity)
        .containerRelativeFrame(.vertical) { height, _ in height * 0.82 }
        .background(AppColor.backgroundPrimary)
        .task { await viewModel.start() }
        .onDisappear { viewModel.cancelStreaming() }
    }

    private var header: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "sparkles").font(.system(size: 15)).foregroundStyle(AppColor.accent)
            Text("AI에게 묻기").font(AppFont.sectionHeader).foregroundStyle(AppColor.ink)
            Spacer()
            Button { onClose() } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(AppColor.textMuted2)
                    .frame(width: 30, height: 30).background(AppColor.surfaceChip).clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.vertical, AppSpacing.md)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    ForEach(Array(viewModel.messages.enumerated()), id: \.offset) { index, message in
                        Bubble(
                            message: message,
                            showTyping: index == viewModel.messages.count - 1 && viewModel.isAwaitingFirstChunk
                        )
                        .id(index)
                    }
                    if viewModel.errorMessage != nil { errorRow }
                    Color.clear.frame(height: 1).id(bottomAnchor)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.md)
            }
            .onChange(of: viewModel.messages.last?.text) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(bottomAnchor, anchor: .bottom) }
            }
        }
    }

    private var errorRow: some View {
        HStack(spacing: AppSpacing.sm) {
            Text(viewModel.errorMessage ?? "").font(AppFont.bodyStrong).foregroundStyle(AppColor.textMuted)
            Button("다시 시도") { viewModel.retry() }.font(AppFont.metaCaption).foregroundStyle(AppColor.accentDeep)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inputArea: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if !viewModel.suggestions.isEmpty && !viewModel.isStreaming {
                Text("이런 점이 궁금하다면").font(AppFont.microCaption).foregroundStyle(AppColor.textMuted2)
                FlowLayout {
                    ForEach(viewModel.suggestions, id: \.self) { question in
                        Button { viewModel.send(question) } label: { Pill(question, style: .accentSoft) }
                            .buttonStyle(.plain)
                    }
                }
            }
            HStack(spacing: AppSpacing.sm) {
                TextField("궁금한 점을 입력해 보세요", text: $viewModel.input, axis: .vertical)
                    .font(AppFont.newsTitle).foregroundStyle(AppColor.ink).lineLimit(1...3)
                    .submitLabel(.send).onSubmit { viewModel.send() }
                    .padding(.leading, AppSpacing.md)
                Button { viewModel.send() } label: {
                    Image(systemName: "arrow.right").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(canSend ? AppColor.accent : AppColor.ctaDisabledBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.chip))
                }
                .buttonStyle(.plain).disabled(!canSend)
            }
            .padding(AppSpacing.xs)
            .background(AppColor.surfaceChip)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.row))
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.lg)
        .background(AppColor.surface)
        .overlay(alignment: .top) { Rectangle().fill(AppColor.hairline).frame(height: 1) }
    }

    private var canSend: Bool {
        !viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isStreaming
    }

    private let bottomAnchor = "chat-bottom"
}

// MARK: - 말풍선
private struct Bubble: View {
    let message: ChatMessage
    let showTyping: Bool

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: AppSpacing.xl) }
            Group {
                if showTyping {
                    TypingDots()
                } else {
                    Text(message.text)
                        .font(AppFont.bodyStrong).foregroundStyle(isUser ? .white : AppColor.ink)
                        .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, AppSpacing.md).padding(.vertical, AppSpacing.sm)
            .background(isUser ? AppColor.accent : AppColor.surfaceChip)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            if !isUser { Spacer(minLength: AppSpacing.xl) }
        }
    }
}

private struct TypingDots: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(AppColor.textMuted2).frame(width: 6, height: 6)
                    .opacity(phase == i ? 1 : 0.35)
            }
        }
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
    }
}
