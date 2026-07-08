import XCTest
@testable import sttak

/// QuizViewModel 문항별 상태 전이 — 페이크 repo(서버 응답 스크립트)로 서버 SSOT 흐름 검증.
/// 페이크 서버 스크립트가 돌려주는 쿨다운 종료 시각(파일 상수 — actor 격리 밖).
private let fakeCooldownEnd = Date(timeIntervalSince1970: 2_000_000)

@MainActor
final class QuizPerQuestionFlowTests: XCTestCase {

    /// 서버를 흉내내는 페이크 — 문항 2개짜리 사이클(총 2문제)로 축약해 전이만 본다.
    private actor FakeQuizRepository: QuizRepository {
        var answered = 0
        let total = 2
        var completedAt: Date?
        var submitError: RepositoryError?

        func setSubmitError(_ error: RepositoryError?) { submitError = error }

        func nextQuestion() async throws -> QuizNextState {
            if completedAt != nil {
                return .cooldown(nextAvailableAt: fakeCooldownEnd)
            }
            let pending = PendingQuizQuestion(
                id: "q\(answered)",
                question: "문제 \(answered + 1)",
                options: ["A", "B", "C", "D"],
                category: nil
            )
            return .question(pending, answeredInCycle: answered, totalInCycle: total)
        }

        func submitAnswer(quizId: String, selectedIndex: Int) async throws -> QuizAnswerResult {
            if let submitError { throw submitError }
            let isCorrect = selectedIndex == 0 // 항상 A가 정답인 스크립트
            answered += 1
            let completed = answered >= total
            if completed { completedAt = Date(timeIntervalSince1970: 1_000_000) }
            return QuizAnswerResult(
                quizId: quizId,
                selectedIndex: selectedIndex,
                correctIndex: 0,
                isCorrect: isCorrect,
                explanation: "해설 \(quizId)",
                earnedCapital: .krw(isCorrect ? 500_000 : 0),
                answeredInCycle: answered,
                totalInCycle: total,
                completed: completed,
                nextAvailableAt: completed ? fakeCooldownEnd : nil
            )
        }

        func lastCompletion() async throws -> QuizCompletion? {
            guard let completedAt else { return nil }
            return QuizCompletion(takenAt: completedAt, correctCount: 1, earnedCapital: .krw(500_000))
        }

        #if DEBUG
        func debugClearCooldown() async throws {}
        #endif
    }

    private func makeViewModel(repo: FakeQuizRepository) -> QuizViewModel {
        QuizViewModel(quiz: repo, portfolio: MockPortfolioRepository(store: MockLocalStore(cash: 1_000_000)))
    }

    func testFlow_submitRevealAdvanceComplete() async throws {
        let repo = FakeQuizRepository()
        let vm = makeViewModel(repo: repo)

        await vm.load()
        XCTAssertEqual(vm.phase, .playing)
        XCTAssertEqual(vm.totalCount, 2)
        XCTAssertEqual(vm.currentIndex, 0)
        XCTAssertFalse(vm.primaryButtonEnabled) // 선택 전엔 제출 불가

        // 1번 문항: 정답(A) 제출 → 서버 채점 공개.
        vm.selectOption(0)
        XCTAssertTrue(vm.primaryButtonEnabled)
        await vm.primaryAction()
        XCTAssertTrue(vm.isRevealed)
        XCTAssertEqual(vm.revealedAnswer?.isCorrect, true)
        XCTAssertEqual(vm.revealedAnswer?.earnedCapital, .krw(500_000))
        XCTAssertEqual(vm.primaryButtonLabel, "다음 문제")

        // 다음 문항으로 — 선택·공개 상태 리셋.
        await vm.primaryAction()
        XCTAssertEqual(vm.currentIndex, 1)
        XCTAssertNil(vm.selectedOption)
        XCTAssertFalse(vm.isRevealed)

        // 2번 문항: 오답(B) 제출 → 서버가 정답 인덱스·해설 공개, completed.
        vm.selectOption(1)
        await vm.primaryAction()
        XCTAssertEqual(vm.revealedAnswer?.isCorrect, false)
        XCTAssertEqual(vm.revealedAnswer?.correctIndex, 0)
        XCTAssertEqual(vm.revealedAnswer?.explanation, "해설 q1")
        XCTAssertEqual(vm.primaryButtonLabel, "결과 보기")

        // 결과 — 서버 last 기록이 outcome의 원본, 쿨다운 시각은 서버 응답값.
        await vm.primaryAction()
        XCTAssertEqual(vm.phase, .done)
        XCTAssertEqual(vm.outcome?.correctCount, 1)
        XCTAssertEqual(vm.outcome?.earnedCapital, .krw(500_000))
        XCTAssertEqual(vm.nextAvailableAt, fakeCooldownEnd)
        XCTAssertEqual(vm.recap.map(\.isCorrect), [true, false])

        vm.stopTicking()
    }

    func testLoad_midCycleResume_startsAtServerIndex() async throws {
        let repo = FakeQuizRepository()
        let vm = makeViewModel(repo: repo)

        // 다른 세션에서 1문항 이미 푼 상태를 재현.
        _ = try await repo.submitAnswer(quizId: "q0", selectedIndex: 0)

        await vm.load()
        XCTAssertEqual(vm.phase, .playing)
        XCTAssertEqual(vm.currentIndex, 1) // 서버 answeredInCycle 기준 이어풀기
        XCTAssertEqual(vm.progressNumberText, "2/2")
    }

    func testLoad_cooldown_usesServerNextAvailableAt() async throws {
        let repo = FakeQuizRepository()
        // 사이클 완료 상태.
        _ = try await repo.submitAnswer(quizId: "q0", selectedIndex: 0)
        _ = try await repo.submitAnswer(quizId: "q1", selectedIndex: 1)

        let vm = makeViewModel(repo: repo)
        await vm.load()
        XCTAssertEqual(vm.phase, .cooldown)
        // 로컬 6h 계산이 아니라 서버 값 그대로.
        XCTAssertEqual(vm.nextAvailableAt, fakeCooldownEnd)
        XCTAssertEqual(vm.lastCompletion?.correctCount, 1)

        vm.stopTicking()
    }

    func testSubmitFailure_showsFailed_andReloadResumes() async throws {
        let repo = FakeQuizRepository()
        let vm = makeViewModel(repo: repo)
        await vm.load()

        await repo.setSubmitError(.network)
        vm.selectOption(0)
        await vm.primaryAction()
        guard case .failed = vm.phase else {
            return XCTFail("failed 페이즈를 기대, 실제 \(vm.phase)")
        }

        // 서버가 상태를 갖고 있으므로 재로드하면 같은 문항부터 재개.
        await repo.setSubmitError(nil)
        await vm.load()
        XCTAssertEqual(vm.phase, .playing)
        XCTAssertEqual(vm.currentIndex, 0)
    }
}
