import Foundation

/// 내 순위 합성 — 내 보유 자산을 리더보드에 끼워 위치를 산출하는 순수 함수.
/// (재계산 없음: 내 자산은 EvaluatePortfolio 결과를 그대로 받는다.)
enum RankingPlacement {
    /// 내 자산보다 큰 랭커 수 + 1 = 내 순위. 동률이면 기존 랭커가 앞(내가 뒤).
    /// totalUsers = 리더보드 인원 + 나.
    static func locate(myAsset: Money, in entries: [RankingEntry]) -> (rank: Int, totalUsers: Int) {
        let above = entries.filter { $0.assetValue.amount > myAsset.amount }.count
        return (rank: above + 1, totalUsers: entries.count + 1)
    }
}
