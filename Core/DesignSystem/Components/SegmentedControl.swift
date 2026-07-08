import SwiftUI

// MARK: - SegmentedControl — 세그먼트(탭 토글)
//
// 핸드오프: 트랙 배경 segmentTrack(#EDE9E0), 트랙 padding 4, 항목 radius 10(chipSmall),
//   항목 글자 13.5/600~700.
//   선택  : 칩 배경 surface(흰색) + segmentSelected 그림자, 글자색 = 스타일별(ink 또는 accentDeep).
//   미선택: 배경 투명, 글자 segmentUnselectedText(#9A9485).
// 항목은 [String], 선택은 Binding<Int>. 화면 로직 없음(선택 인덱스만 바인딩).
struct SegmentedControl: View {
    /// 선택 칩 글자색 스타일. 핸드오프에 두 관례가 있음(시트=ink, easyMode/데모=accentDeep).
    enum SelectionStyle {
        case ink
        case accent

        var selectedText: Color {
            switch self {
            case .ink: return AppColor.ink
            case .accent: return AppColor.accentDeep
            }
        }
    }

    private let items: [String]
    @Binding private var selection: Int
    private let style: SelectionStyle

    init(_ items: [String], selection: Binding<Int>, style: SelectionStyle = .ink) {
        self.items = items
        self._selection = selection
        self.style = style
    }

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, label in
                let isSelected = index == selection
                Button {
                    selection = index
                } label: {
                    Text(label)
                        .font(AppFont.bodyStrong)
                        .lineLimit(1)
                        .foregroundStyle(isSelected ? style.selectedText : AppColor.segmentUnselectedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.sm)
                        .background(isSelected ? AppColor.surface : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.chipSmall))
                        .modifier(SelectedChipShadow(selected: isSelected))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.xs)
        .background(AppColor.segmentTrack)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.chip))
    }
}

private struct SelectedChipShadow: ViewModifier {
    let selected: Bool
    func body(content: Content) -> some View {
        if selected {
            content.appShadow(AppShadow.segmentSelected)
        } else {
            content
        }
    }
}

#if DEBUG
private struct SegmentedControlPreview: View {
    @SwiftUI.State private var a = 0
    @SwiftUI.State private var b = 1

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            SegmentedControl(["쉬운풀이", "원문", "AI에게 묻기"], selection: $a, style: .ink)
            SegmentedControl(["신규 유저 → 온보딩", "기존 유저 → 홈"], selection: $b, style: .accent)
        }
        .padding(AppSpacing.screenHorizontal)
        .background(AppColor.backgroundPrimary)
    }
}

#Preview("SegmentedControl") {
    SegmentedControlPreview()
}
#endif
