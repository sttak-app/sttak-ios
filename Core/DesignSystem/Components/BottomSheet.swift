import SwiftUI

// MARK: - BottomSheet — 하단에서 올라오는 시트 (스크림 + 슬라이드업)
//
// 핸드오프: 딤 스크림 위로 흰 시트가 올라옴. 상단 모서리 radius 28(sheet), 배경 surface,
//   그림자 sheet(0 -10px 40px …0.18), 등장 애니메이션 scSheetUp ~0.32s. 스크림 탭 시 닫힘.
// 재사용: 표시 여부는 Binding, 내용은 클로저. 화면 로직 없음(내용/높이는 호출부가 결정).
struct BottomSheet<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    @ViewBuilder let sheetContent: () -> SheetContent

    func body(content: Content) -> some View {
        content.overlay {
            ZStack(alignment: .bottom) {
                if isPresented {
                    AppColor.scrim
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture { isPresented = false }

                    sheetContent()
                        .frame(maxWidth: .infinity)
                        .background(AppColor.surface)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: AppRadius.sheet,
                                topTrailingRadius: AppRadius.sheet
                            )
                        )
                        .appShadow(AppShadow.sheet)
                        .transition(.move(edge: .bottom))
                }
            }
            .animation(.easeOut(duration: 0.32), value: isPresented)
        }
    }
}

extension View {
    /// 하단 시트를 표시한다. 스크림 탭으로 닫힌다.
    func bottomSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        modifier(BottomSheet(isPresented: isPresented, sheetContent: content))
    }
}

#if DEBUG
private struct BottomSheetPreview: View {
    @SwiftUI.State private var presented = false

    var body: some View {
        ZStack {
            AppColor.backgroundPrimary.ignoresSafeArea()
            PrimaryButton("시트 열기") { presented = true }
                .padding(AppSpacing.screenHorizontal)
        }
        .bottomSheet(isPresented: $presented) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("뉴스 상세")
                    .font(AppFont.focusCardTitle)
                    .foregroundStyle(AppColor.ink)
                Text("스크림을 탭하면 닫혀요.")
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.cardPadding)
            .padding(.bottom, AppSpacing.xxl)
        }
    }
}

#Preview("BottomSheet") {
    BottomSheetPreview()
}
#endif
