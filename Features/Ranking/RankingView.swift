import SwiftUI

/// 랭킹 — 보유 자산 단일 리더보드. 마이의 "랭킹 현황 > 전체 보기"로 진입.
struct RankingView: View {
    @Environment(\.container) private var container
    @State private var viewModel: RankingViewModel?

    var body: some View {
        ZStack {
            AppColor.backgroundPrimary.ignoresSafeArea()
            if let viewModel {
                content(viewModel)
            } else {
                ProgressView().tint(AppColor.accent)
            }
        }
        .navigationTitle("랭킹").navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil { viewModel = container.makeRankingViewModel() }
            await viewModel?.load()
        }
    }

    @ViewBuilder
    private func content(_ viewModel: RankingViewModel) -> some View {
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
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    MyRankHero(viewModel: viewModel)
                    HStack {
                        Text("상위 랭커").font(AppFont.sectionHeader).foregroundStyle(AppColor.ink)
                        Spacer()
                        Text("순위 변동은 1시간 전 대비").font(AppFont.microCaption).foregroundStyle(AppColor.textMuted2)
                    }
                    leaderboard(viewModel)
                    MyRow(viewModel: viewModel)
                    Text("순위는 실시간으로 갱신돼요 · 모의 데이터 기준")
                        .font(AppFont.microCaption).foregroundStyle(AppColor.textMuted2)
                        .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.lg)
            }
        }
    }

    private func leaderboard(_ viewModel: RankingViewModel) -> some View {
        VStack(spacing: 0) {
            ForEach(viewModel.entries, id: \.rank) { entry in
                LeaderboardRow(entry: entry, subReturn: viewModel.returnRate(of: entry))
                if entry.rank != viewModel.entries.last?.rank {
                    Rectangle().fill(AppColor.hairline2).frame(height: 1)
                }
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.banner)).appShadow(AppShadow.card)
    }
}

// MARK: - 내 순위 히어로(다크)
private struct MyRankHero: View {
    let viewModel: RankingViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("내 순위").font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted2)
                Spacer()
                Text("전체 \(viewModel.totalUsers)명").font(AppFont.metaCaption).foregroundStyle(AppColor.textMuted2)
            }
            HStack(alignment: .lastTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("#").font(AppFont.number(15)).foregroundStyle(AppColor.textMuted2)
                    Text("\(viewModel.myRank)").font(AppFont.numberHero).foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                    Text("보유 자산").font(AppFont.microCaption).foregroundStyle(AppColor.textMuted2)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(Formatters.grouped(viewModel.myAsset.amount)).font(AppFont.numberLarge).foregroundStyle(AppColor.accentBright)
                        Text(" 원").font(AppFont.microCaption).foregroundStyle(AppColor.textMuted2)
                    }
                    Text("수익률 \(Formatters.signedPercent(viewModel.myReturnRate, fractionDigits: 1))")
                        .font(AppFont.number(12)).foregroundStyle(AppColor.textMuted)
                }
            }
            .padding(.top, AppSpacing.md)

            HStack(spacing: AppSpacing.md) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.12))
                        Capsule().fill(AppColor.accent)
                            .frame(width: geo.size.width * CGFloat(max(1, 101 - viewModel.topPercent)) / 100)
                    }
                }
                .frame(height: 7)
                Text("상위 \(viewModel.topPercent)%").font(AppFont.number(12)).foregroundStyle(AppColor.accentBright)
            }
            .padding(.top, AppSpacing.md)
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.ink)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.banner))
    }
}

// MARK: - 리더보드 행
private struct LeaderboardRow: View {
    let entry: RankingEntry
    let subReturn: Double
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            RankBadge(rank: entry.rank)
            Avatar(name: entry.nickname, rank: entry.rank)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.nickname).font(AppFont.listItem).foregroundStyle(AppColor.ink).lineLimit(1)
                Text("수익률 \(Formatters.signedPercent(subReturn, fractionDigits: 1))").font(AppFont.microCaption).foregroundStyle(AppColor.textMuted2)
            }
            Spacer(minLength: AppSpacing.xs)
            Text("\(Formatters.grouped(entry.assetValue.amount))").font(AppFont.number(14)).foregroundStyle(AppColor.ink)
            + Text(" 원").font(AppFont.microCaption).foregroundStyle(AppColor.textMuted2)
            RankChange(change: entry.rankChange)
        }
        .padding(.vertical, AppSpacing.md)
    }
}

// MARK: - 내 행(강조)
private struct MyRow: View {
    let viewModel: RankingViewModel
    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { _ in Circle().fill(AppColor.controlBorder).frame(width: 3, height: 3) }
            }
            HStack(spacing: AppSpacing.sm) {
                Text("\(viewModel.myRank)").font(AppFont.number(14)).foregroundStyle(AppColor.accentDeep).frame(width: 30)
                Avatar(name: viewModel.myNickname, rank: 0, isMe: true)
                HStack(spacing: AppSpacing.xs) {
                    Text(viewModel.myNickname).font(AppFont.listItem).foregroundStyle(AppColor.accentDeep).lineLimit(1)
                    Text("나").font(AppFont.microCaption).foregroundStyle(AppColor.accentDeep)
                        .padding(.horizontal, AppSpacing.xs).padding(.vertical, 1)
                        .background(AppColor.accentTintSoft).clipShape(RoundedRectangle(cornerRadius: AppRadius.badge))
                }
                Spacer(minLength: AppSpacing.xs)
                Text("\(Formatters.grouped(viewModel.myAsset.amount))").font(AppFont.number(14)).foregroundStyle(AppColor.accentDeep)
                + Text(" 원").font(AppFont.microCaption).foregroundStyle(AppColor.accentDeep.opacity(0.7))
            }
            .padding(AppSpacing.md)
            .background(AppColor.accentTintSoft)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.accentTintBorder, lineWidth: 1.5))
        }
    }
}

// MARK: - 부품
private struct RankBadge: View {
    let rank: Int
    var body: some View {
        Group {
            if let medal = medalColor {
                Text("\(rank)").font(AppFont.number(12)).foregroundStyle(medal)
                    .frame(width: 26, height: 26).background(medal.opacity(0.15)).clipShape(Circle())
            } else {
                Text("\(rank)").font(AppFont.number(14)).foregroundStyle(AppColor.textMuted2).frame(width: 26)
            }
        }
        .frame(width: 30)
    }
    private var medalColor: Color? {
        switch rank {
        case 1: return AppColor.leagueGold
        case 2: return AppColor.leagueSilver
        case 3: return AppColor.leagueBronze
        default: return nil
        }
    }
}

private struct RankChange: View {
    let change: Int
    var body: some View {
        HStack(spacing: 1) {
            Image(systemName: icon).font(.system(size: 9, weight: .heavy)).foregroundStyle(color)
            if change != 0 { Text("\(abs(change))").font(AppFont.number(11)).foregroundStyle(color) }
        }
        .frame(width: 30, alignment: .trailing)
        .opacity(change == 0 ? 0.7 : 1)
    }
    // 순위 상승=초록/하락=로즈/유지=회색 (가격 등락과 다른 색계, 핸드오프 #1F8A57/#C77E7E/#BDB6A7)
    private var color: Color { change > 0 ? AppColor.rankUp : (change < 0 ? AppColor.rankDown : AppColor.rankFlat) }
    private var icon: String { change > 0 ? "chevron.up" : (change < 0 ? "chevron.down" : "minus") }
}

private struct Avatar: View {
    let name: String
    let rank: Int
    var isMe = false
    var body: some View {
        Text(String(name.prefix(1)))
            .font(AppFont.number(13)).foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(isMe ? AppColor.accent : Self.palette[rank % Self.palette.count])
            .clipShape(Circle())
    }
    private static let palette: [Color] = [AppColor.indicatorMA, AppColor.priceDown, AppColor.accent, AppColor.indicatorRSI]
}
