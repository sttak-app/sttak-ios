import XCTest
@testable import sttak

/// 쿨다운 중 재응시 거부 — 실제 QuizViewModel + MockQuizRepository(문항별 채점) 흐름.
@MainActor
final class QuizCooldownGatingTests: XCTestCase {

    func testRetake_afterCompletion_entersCooldown() async throws {
        let store = MockLocalStore(cash: 10_000_000)
        let quiz = MockQuizRepository(store: store)
        let portfolio = MockPortfolioRepository(store: store)
        let vm = QuizViewModel(quiz: quiz, portfolio: portfolio)

        await vm.load()
        XCTAssertEqual(vm.phase, .playing) // 이력 없음 → 풀 수 있음

        // 3문제 모두 정답으로 진행(선택 → 제출/채점 → 다음/결과).
        for i in 0..<vm.totalCount {
            vm.selectOption(MockData.quizQuestions[i].answerIndex)
            await vm.primaryAction() // 제출 → 서버(재현) 채점 공개
            XCTAssertTrue(vm.isRevealed)
            XCTAssertTrue(vm.wasCurrentCorrect)
            await vm.primaryAction() // 다음 / 결과
        }
        XCTAssertEqual(vm.phase, .done)
        XCTAssertEqual(vm.outcome?.correctCount, 3)

        // 자본금 적립이 포트폴리오에 반영(3정답 → +150만).
        let p = try await portfolio.fetchPortfolio()
        XCTAssertEqual(p.cash.amount, 11_500_000)
        XCTAssertEqual(vm.currentCapital, 11_500_000)

        // 막 응시했으므로 재진입 시 쿨다운(6h 경과 전) — 쿨다운 시각은 repo(서버 SSOT) 응답값.
        await vm.load()
        XCTAssertEqual(vm.phase, .cooldown)
        XCTAssertNotNil(vm.nextAvailableAt)

        vm.stopTicking()
    }
}
