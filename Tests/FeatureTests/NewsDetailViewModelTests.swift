import XCTest
@testable import sttak

/// 뉴스 상세 AI 스트리밍 상태머신 테스트 — 누적·완료·취소·재진입(시뮬레이터 탭 불가하므로 결정적 검증).
@MainActor
final class NewsDetailViewModelTests: XCTestCase {

    private func sampleNews() -> NewsItem {
        NewsItem(
            sentiment: .neutral, title: "t", easy: "e", summary: "s", whyPoints: [], reason: "r",
            terms: [], source: "src", publishedAt: Date(timeIntervalSince1970: 0), originalURL: nil, lead: "l"
        )
    }

    private func makeViewModel() -> NewsDetailViewModel {
        // 빠른 스트리밍(지연 0)으로 결정적 테스트.
        NewsDetailViewModel(news: sampleNews(), stockName: "삼성전자", chat: MockChatRepository(chunkDelay: .zero))
    }

    func testAsk_accumulatesFullAnswer_andCompletes() async throws {
        let vm = makeViewModel()
        let question = MockData.quickAnswers[0].question
        vm.ask(question)
        await waitUntilNotStreaming(vm)

        XCTAssertEqual(vm.streamingState, .done)
        XCTAssertEqual(vm.messages.count, 2)
        XCTAssertEqual(vm.messages[0].role, .user)
        XCTAssertEqual(vm.messages[0].text, question)
        XCTAssertEqual(vm.messages[1].role, .assistant)
        XCTAssertEqual(vm.messages[1].text, MockData.quickAnswers[0].answer) // 전체 누적
    }

    func testCancel_stopsStreaming_noFurtherGrowth() async throws {
        // 지연이 있어야 중간에 취소 가능.
        let vm = NewsDetailViewModel(news: sampleNews(), stockName: "삼", chat: MockChatRepository(chunkDelay: .milliseconds(5)))
        vm.ask("어려운 말 없이 설명해줘")
        try await Task.sleep(for: .milliseconds(20)) // 몇 글자 누적
        vm.cancelStreaming()
        await waitUntilNotStreaming(vm)

        XCTAssertEqual(vm.streamingState, .cancelled)
        let lengthAfterCancel = vm.messages.last?.text.count ?? 0
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertEqual(vm.messages.last?.text.count, lengthAfterCancel) // 잔여 작업 없음
    }

    func testReask_whileStreaming_isIgnored() async throws {
        let vm = NewsDetailViewModel(news: sampleNews(), stockName: "삼", chat: MockChatRepository(chunkDelay: .milliseconds(5)))
        vm.ask("이게 왜 중요한가요?")
        vm.ask("주가에 어떤 영향이 있나요?") // 진행 중이라 무시되어야 함
        XCTAssertEqual(vm.messages.count, 2) // 한 쌍만
        vm.cancelStreaming()
        await waitUntilNotStreaming(vm)
    }

    func testReentry_afterDone_startsFreshTurn() async throws {
        let vm = makeViewModel()
        vm.ask(MockData.quickAnswers[0].question)
        await waitUntilNotStreaming(vm)
        vm.ask(MockData.quickAnswers[1].question)
        await waitUntilNotStreaming(vm)

        XCTAssertEqual(vm.messages.count, 4) // 두 쌍
        XCTAssertEqual(vm.streamingState, .done)
    }

    func testTabSwitchAwayFromAI_cancelsStreaming() async throws {
        let vm = NewsDetailViewModel(news: sampleNews(), stockName: "삼", chat: MockChatRepository(chunkDelay: .milliseconds(5)))
        vm.selectedTab = .ai
        vm.ask("이게 왜 중요한가요?")
        try await Task.sleep(for: .milliseconds(15))
        vm.selectedTab = .easy // AI 떠남 → 취소
        await waitUntilNotStreaming(vm)
        XCTAssertEqual(vm.streamingState, .cancelled)
    }

    // 스트리밍이 끝날 때까지 대기(최대 ~2초 안전장치).
    private func waitUntilNotStreaming(_ vm: NewsDetailViewModel) async {
        for _ in 0..<400 {
            if vm.streamingState != .streaming { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
    }
}
