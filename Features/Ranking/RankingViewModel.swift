import SwiftUI

/// 랭킹 — 보유 자산 단일 리더보드 + 내 순위 합성. 내 자산은 EvaluatePortfolio 재사용(마이와 동일 값).
@MainActor
@Observable
final class RankingViewModel {
    enum Phase: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    private(set) var phase: Phase = .loading
    private(set) var entries: [RankingEntry] = []   // 상위권(자산 내림차순)
    private(set) var myRank = 0
    private(set) var totalUsers = 0
    private(set) var myAsset = Money.krw(0)
    private(set) var myReturnRate = 0.0
    private(set) var myNickname = "나"

    private let ranking: RankingRepository
    private let evaluate: EvaluatePortfolio
    private let auth: AuthRepository

    init(ranking: RankingRepository, evaluate: EvaluatePortfolio, auth: AuthRepository) {
        self.ranking = ranking
        self.evaluate = evaluate
        self.auth = auth
    }

    /// 상위 백분위(작을수록 상위). rank/total × 100.
    var topPercent: Int {
        totalUsers > 0 ? max(1, Int((Double(myRank) / Double(totalUsers) * 100).rounded())) : 0
    }

    /// 한 랭커의 수익률(시작 자본 대비) — 표시용.
    func returnRate(of entry: RankingEntry) -> Double {
        Double(entry.assetValue.amount - EvaluatePortfolio.startingCapital) / Double(EvaluatePortfolio.startingCapital) * 100
    }

    func load() async {
        phase = .loading
        do {
            let snapshot = try await ranking.fetchRanking()
            let valuation = try await evaluate()
            if let user = (try? await auth.currentUser()) ?? nil { myNickname = user.nickname }

            myAsset = valuation.totalAssets       // 마이 화면 평가자산과 같은 값
            myReturnRate = valuation.returnRate
            let placement = RankingPlacement.locate(myAsset: myAsset, in: snapshot.entries)
            myRank = placement.rank
            totalUsers = placement.totalUsers
            entries = snapshot.entries
            phase = .loaded
        } catch {
            phase = .failed("랭킹을 불러오지 못했어요.")
        }
    }
}
