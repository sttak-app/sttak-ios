import Foundation

/// 회고 Mock. 매도 직후 회고를 점진 스트리밍(요약→잘한점→함께볼점), 후속 회고는 결정적 시뮬레이션.
/// 회고 문구는 `sttak 차트학습.dc.html` buildRetro/ followText 를 이식.
/// 실현 손익(매도가−평단) 부호로 win/loss 두 번째 잘한점을 분기한다(커밋 11 합의).
struct MockRetrospectiveRepository: RetrospectiveRepository {
    var stepDelay: Duration = .milliseconds(250)

    private static let firstGood = "매매 전에 이유를 적어 둔 점이 좋아요. 막연한 감이 아니라 근거를 남겼어요."
    private static let winGood = "수익을 실현해 계획을 행동으로 옮겼어요. 이익을 지키는 것도 중요한 연습이에요."
    private static let lossGood = "손실을 키우지 않고 정리한 것도 하나의 선택이에요. 다음 판단을 위한 여유를 남겼어요."
    private static let partialWatch = "일부만 매도했어요. 남은 수량의 계획도 함께 세워 두면 좋아요."
    private static let watchPoints = [
        "매도 전에 거래량·이동평균선 흐름도 같이 봤다면 판단이 더 단단했을 거예요.",
        "근거에 적은 기대가 실제로 맞았는지 한 달 뒤에 다시 비교해 보세요.",
    ]

    func generateRetrospective(
        for trade: Trade,
        realizedProfit: Money,
        isPartialSell: Bool
    ) -> AsyncThrowingStream<Retrospective, Error> {
        let delay = stepDelay
        let id = "retro-\(trade.id)"
        let summary = "\(trade.quantity)주 · \(Self.grouped(trade.price.amount))원에 매도"
        let good = [Self.firstGood, realizedProfit.amount >= 0 ? Self.winGood : Self.lossGood]
        let watch = (isPartialSell ? [Self.partialWatch] : []) + Self.watchPoints
        return AsyncThrowingStream { continuation in
            let task = Task {
                func snapshot(_ good: [String], _ watch: [String]) -> Retrospective {
                    Retrospective(
                        id: id, summaryLine: summary, goodPoints: good, watchPoints: watch,
                        isPartialSell: isPartialSell, createdAt: Date(), followUp: nil
                    )
                }
                do {
                    continuation.yield(snapshot([], []))
                    try await Task.sleep(for: delay)
                    continuation.yield(snapshot(good, []))
                    try await Task.sleep(for: delay)
                    continuation.yield(snapshot(good, watch))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func generateFollowUp(for trade: Trade) async throws -> FollowUpRetrospective {
        // buildRetro의 결정적 해시 → 미래가/변화율.
        let key = trade.stockCode + String(Int(trade.executedAt.timeIntervalSince1970)) + String(trade.quantity)
        var hash = 0
        for scalar in key.unicodeScalars { hash = (hash &* 31 &+ Int(scalar.value)) & 0xffff }
        let f = (Double(hash % 1000) / 1000 - 0.42) * 0.22
        let futPrice = Int((Double(trade.price.amount) * (1 + f) / 10).rounded()) * 10
        let diffPercent = Double(futPrice - trade.price.amount) / Double(trade.price.amount) * 100

        let text = diffPercent >= 0
            ? "한 달 뒤엔 매도가보다 더 올랐어요. 더 가져갔다면 좋았겠지만, 그때 정보로는 충분히 합리적인 선택이었어요. ‘더 보유할지’는 늘 어려운 판단이에요."
            : "한 달 뒤엔 매도가보다 더 내렸어요. 그 시점에 정리한 판단이 결과적으로 손실을 줄였네요. 매번 이렇게 맞지는 않으니, 근거를 남기는 습관이 가장 큰 자산이에요."

        return FollowUpRetrospective(
            evaluatedAt: trade.executedAt.addingTimeInterval(30 * 86_400),
            priceAtFollowUp: .krw(futPrice),
            comparisonText: text
        )
    }

    private static func grouped(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
