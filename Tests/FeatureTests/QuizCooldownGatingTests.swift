import XCTest
@testable import sttak

/// 쿨다운 중 재응시 거부 — 실제 QuizViewModel + ScoreQuizAndAwardCapital + creditCash 흐름.
@MainActor
final class QuizCooldownGatingTests: XCTestCase {

    func testRetake_afterCompletion_entersCooldown() async throws {
        let store = MockLocalStore(cash: 10_000_000)
        let quiz = MockQuizRepository(store: store)
        let portfolio = MockPortfolioRepository(store: store)
        let vm = QuizViewModel(
            score: ScoreQuizAndAwardCapital(portfolio: portfolio, quiz: quiz),
            quiz: quiz, portfolio: portfolio
        )

        await vm.load()
        XCTAssertEqual(vm.phase, .playing) // 이력 없음 → 풀 수 있음

        // 3문제 모두 정답으로 진행(선택 → 정답확인 → 다음/결과).
        for _ in 0..<vm.totalCount {
            if let answer = vm.currentQuestion?.answerIndex { vm.selectOption(answer) }
            await vm.primaryAction() // 정답 확인
            await vm.primaryAction() // 다음 / 결과
        }
        XCTAssertEqual(vm.phase, .done)

        // 자본금 적립이 포트폴리오에 반영(3정답 → +150만).
        let p = try await portfolio.fetchPortfolio()
        XCTAssertEqual(p.cash.amount, 11_500_000)

        // 막 응시했으므로 재진입 시 쿨다운(6h 경과 전).
        await vm.load()
        XCTAssertEqual(vm.phase, .cooldown)

        vm.stopTicking()
    }
}
