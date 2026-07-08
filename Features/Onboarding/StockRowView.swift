import SwiftUI

/// 종목 선택 행(검색 결과·인기종목 공용). 핸드오프: 배지 + 이름/코드·시장 + 가격/등락 + 선택 체크.
/// 선택 시 행 배경 틸 틴트 + 틸 보더.
struct StockRowView: View {
    let stock: Stock
    let quote: Quote?
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: AppSpacing.md) {
                StockInitialBadge(name: stock.name)

                VStack(alignment: .leading, spacing: 2) {
                    Text(stock.name)
                        .font(AppFont.listItem)
                        .foregroundStyle(AppColor.ink)
                        .lineLimit(1)
                    Text("\(stock.code) · \(marketLabel)")
                        .font(AppFont.metaCaption)
                        .foregroundStyle(AppColor.textMuted2)
                }

                Spacer(minLength: AppSpacing.sm)

                if let quote, quote.price.amount > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Formatters.grouped(quote.price.amount))
                            .font(AppFont.number(14))
                            .foregroundStyle(AppColor.ink)
                        Text(Formatters.signedPercent(quote.changePercent))
                            .font(AppFont.number(12))
                            .foregroundStyle(quote.changePercent >= 0 ? AppColor.priceUp : AppColor.priceDown)
                    }
                }

                SelectionCircle(isSelected: isSelected)
            }
            .padding(AppSpacing.md)
            .background(isSelected ? AppColor.accentTint : AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(isSelected ? AppColor.accentTintBorder : AppColor.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var marketLabel: String {
        switch stock.market {
        case .kospi: return "KOSPI"
        case .kosdaq: return "KOSDAQ"
        }
    }
}

/// 종목 이니셜 배지(이름 앞 2글자). 핸드오프의 회색 사각 배지를 종이톤 토큰으로 재현.
struct StockInitialBadge: View {
    let name: String
    var body: some View {
        Text(String(name.prefix(2)))
            .font(AppFont.metaCaption)
            .foregroundStyle(AppColor.inkSoft)
            .frame(width: 40, height: 40)
            .background(AppColor.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.chip))
    }
}

/// 선택 체크 원(틸 채움+흰 체크 / 미선택 보더).
struct SelectionCircle: View {
    let isSelected: Bool
    var body: some View {
        ZStack {
            if isSelected {
                Circle().fill(AppColor.accent)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle().strokeBorder(AppColor.controlBorder, lineWidth: 2)
            }
        }
        .frame(width: 24, height: 24)
    }
}
