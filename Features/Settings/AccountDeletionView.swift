import SwiftUI

/// 회원탈퇴 확인 화면 (Apple 5.1.1(v) 준수): 영구 삭제·복구 불가·처리 시간 고지 →
/// 명시적 확인("이해했습니다") → 삭제 → 로그인 복귀.
struct AccountDeletionView: View {
    @Bindable var viewModel: SettingsViewModel
    let onSignedOut: () -> Void
    @State private var acknowledged = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 28)).foregroundStyle(AppColor.destructive)
                    Text("정말 탈퇴하실까요?").font(AppFont.resultTitle).foregroundStyle(AppColor.ink)
                }
                .padding(.top, AppSpacing.sm)

                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    bullet("계정과 모든 학습 기록(포트폴리오·매매·회고·퀴즈)이 영구 삭제돼요.")
                    bullet("삭제된 데이터는 복구할 수 없어요.")
                    bullet("처리에는 영업일 기준 최대 7일이 걸릴 수 있어요.")
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.destructive.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))

                Button { acknowledged.toggle() } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: acknowledged ? "checkmark.square.fill" : "square")
                            .font(.system(size: 20)).foregroundStyle(acknowledged ? AppColor.destructive : AppColor.controlBorder)
                        Text("위 내용을 모두 이해했습니다").font(AppFont.bodyStrong).foregroundStyle(AppColor.inkSoft)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                Button { Task { if await viewModel.deleteAccount() { onSignedOut() } } } label: {
                    HStack(spacing: AppSpacing.sm) {
                        if viewModel.isProcessing { ProgressView().tint(.white) }
                        Text("회원탈퇴하기").font(AppFont.ctaLabel).foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(acknowledged ? AppColor.destructive : AppColor.ctaDisabledBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                }
                .buttonStyle(.plain)
                .disabled(!acknowledged || viewModel.isProcessing)

                Text("탈퇴 대신 로그아웃으로 잠시 쉬어갈 수도 있어요.")
                    .font(AppFont.microCaption).foregroundStyle(AppColor.textMuted2)
                    .frame(maxWidth: .infinity).multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.lg)
        }
        .background(AppColor.backgroundPrimary)
        .navigationTitle("회원탈퇴").navigationBarTitleDisplayMode(.inline)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Circle().fill(AppColor.destructive).frame(width: 5, height: 5).padding(.top, 7)
            Text(text).font(AppFont.bodyStrong).foregroundStyle(AppColor.inkSoft).lineSpacing(3)
        }
    }
}
