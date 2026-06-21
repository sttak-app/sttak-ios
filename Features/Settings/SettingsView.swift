import SwiftUI

/// 설정 화면. 마이 우상단 톱니로 진입. 알림 토글 · 서비스 안내 · 약관 · 로그아웃 · 회원탈퇴.
struct SettingsView: View {
    @Environment(\.container) private var container
    @State private var viewModel: SettingsViewModel?
    var onSignedOut: () -> Void = {}

    var body: some View {
        ZStack {
            AppColor.backgroundPrimary.ignoresSafeArea()
            if let viewModel {
                SettingsContent(viewModel: viewModel, onSignedOut: onSignedOut)
            } else {
                ProgressView().tint(AppColor.accent)
            }
        }
        .navigationTitle("설정").navigationBarTitleDisplayMode(.inline)
        .task { if viewModel == nil { viewModel = container.makeSettingsViewModel() } }
    }
}

private struct SettingsContent: View {
    @Bindable var viewModel: SettingsViewModel
    let onSignedOut: () -> Void
    @State private var showLogoutConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                section("알림") {
                    SettingsCard {
                        toggleRow("후속 회고 알림", "한 달 뒤 후속 회고가 도착하면 알려드려요", $viewModel.followUpRetroEnabled)
                        divider
                        toggleRow("퀴즈 알림", "새 퀴즈 3문제가 열리면 알려드려요", $viewModel.quizReminderEnabled)
                        divider
                        toggleRow("랭킹 변동 알림", "순위가 크게 바뀌면 알려드려요", $viewModel.rankingChangeEnabled)
                    }
                    Text("알림은 기기 설정에서도 끌 수 있어요.").font(AppFont.microCaption).foregroundStyle(AppColor.textMuted2)
                }

                section("서비스 안내") {
                    SettingsCard {
                        infoRow("앱 버전", "v\(viewModel.appVersion)")
                        divider
                        NavigationLink { TermsStubView(title: "문의하기") } label: { linkRowLabel("문의하기") }.buttonStyle(.plain)
                    }
                }

                section("약관 및 정책") {
                    SettingsCard {
                        NavigationLink { TermsStubView(title: "이용약관") } label: { linkRowLabel("이용약관") }.buttonStyle(.plain)
                        divider
                        NavigationLink { TermsStubView(title: "개인정보처리방침") } label: { linkRowLabel("개인정보처리방침") }.buttonStyle(.plain)
                    }
                }

                // 로그아웃(가역)
                SettingsCard {
                    Button { showLogoutConfirm = true } label: {
                        HStack {
                            Text("로그아웃").font(AppFont.listItem).foregroundStyle(AppColor.destructive)
                            Spacer()
                            Image(systemName: "rectangle.portrait.and.arrow.right").font(.system(size: 14)).foregroundStyle(AppColor.destructive)
                        }
                        .padding(AppSpacing.md)
                    }
                    .buttonStyle(.plain)
                }

                // 회원탈퇴 — 맨 아래, 구분선으로 분리, 작고 차분하게(destructive)
                VStack(spacing: AppSpacing.sm) {
                    Rectangle().fill(AppColor.hairline2).frame(height: 1)
                    NavigationLink {
                        AccountDeletionView(viewModel: viewModel, onSignedOut: onSignedOut)
                    } label: {
                        Text("회원탈퇴").font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted)
                            .frame(maxWidth: .infinity).padding(.vertical, AppSpacing.sm)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, AppSpacing.sm)

                Text("sttak · 모의 투자 학습").font(AppFont.microCaption).foregroundStyle(AppColor.textMuted2)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.lg)
        }
        .alert("로그아웃할까요?", isPresented: $showLogoutConfirm) {
            Button("로그아웃", role: .destructive) { Task { if await viewModel.logout() { onSignedOut() } } }
            Button("취소", role: .cancel) {}
        } message: {
            Text("다시 로그인하면 이어서 학습할 수 있어요.")
        }
    }

    // MARK: 부품
    private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title).font(AppFont.sectionHeader).foregroundStyle(AppColor.ink)
            content()
        }
    }

    private func toggleRow(_ title: String, _ subtitle: String, _ isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppFont.listItem).foregroundStyle(AppColor.ink)
                Text(subtitle).font(AppFont.microCaption).foregroundStyle(AppColor.textMuted2)
            }
        }
        .tint(AppColor.accent)
        .padding(AppSpacing.md)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(AppFont.listItem).foregroundStyle(AppColor.ink)
            Spacer()
            Text(value).font(AppFont.number(13)).foregroundStyle(AppColor.textMuted)
        }
        .padding(AppSpacing.md)
    }

    private func linkRowLabel(_ title: String) -> some View {
        HStack {
            Text(title).font(AppFont.listItem).foregroundStyle(AppColor.ink)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(AppColor.textMuted2)
        }
        .padding(AppSpacing.md)
    }

    private var divider: some View { Rectangle().fill(AppColor.hairline2).frame(height: 1).padding(.leading, AppSpacing.md) }
}

/// 흰 카드 컨테이너.
private struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .appShadow(AppShadow.card)
    }
}

/// 약관/문의 stub — 본문은 Live/후속(웹뷰 자리).
private struct TermsStubView: View {
    let title: String
    var body: some View {
        ZStack {
            AppColor.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: AppSpacing.md) {
                Image(systemName: "doc.text").font(.system(size: 30)).foregroundStyle(AppColor.textMuted2)
                Text("\(title) 본문은 곧 제공돼요").font(AppFont.listItem).foregroundStyle(AppColor.ink)
                Text("정식 출시 시 여기에 표시됩니다.").font(AppFont.bodyStrong).foregroundStyle(AppColor.textMuted)
            }
        }
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}
