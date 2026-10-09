import XCTest
@testable import sttak

/// 뉴스 상세 AI 스트리밍 상태머신 테스트 — 완성본 수신·취소·재진입(시뮬레이터 탭 불가하므로 결정적 검증).
/// 서버 계약: stage*(진행 단계) → answer(완성 본문 1회). Mock도 같은 순서로 흘린다.
@MainActor
final class NewsDetailViewModelTests: XCTestCase {

    private func sampleNews() -> NewsItem {
        NewsItem(
            sentiment: .neutral, title: "t", easy: "e", summary: "s", whyPoints: [], reason: "r",
            terms: [], source: "src", publishedAt: Date(timeIntervalSince1970: 0), originalURL: nil, lead: "l"
        )
    }

    /// 기본은 지연 0(결정적). 취소 검증처럼 중간 상태가 필요하면 eventDelay를 준다.
    private func makeViewModel(eventDelay: Duration = .zero) -> NewsDetailViewModel {
        NewsDetailViewModel(
            news: sampleNews(), stockName: "삼성전자", stockCode: "005930",
            chat: MockChatRepository(eventDelay: eventDelay)
        )
    }

    func testAsk_receivesFullAnswer_andCompletes() async throws {
        let vm = makeViewModel()
        let question = MockData.quickAnswers[0].question
        vm.ask(question)
        await waitUntilNotStreaming(vm)

        XCTAssertEqual(vm.streamingState, .done)
        XCTAssertEqual(vm.messages.count, 2)
        XCTAssertEqual(vm.messages[0].role, .user)
        XCTAssertEqual(vm.messages[0].text, question)
        XCTAssertEqual(vm.messages[1].role, .assistant)
        XCTAssertEqual(vm.messages[1].text, MockData.quickAnswers[0].answer) // 완성본 일괄 수신
        XCTAssertNil(vm.stage) // 완료 후 진행 단계 해제
    }

    func testCancel_stopsStreaming_noFurtherGrowth() async throws {
        // 이벤트 간격이 넉넉해야 answer 도착 전(진행 단계 표시 중)에 취소할 수 있다.
        let vm = makeViewModel(eventDelay: .milliseconds(100))
        vm.ask("어려운 말 없이 설명해줘")
        try await Task.sleep(for: .milliseconds(20)) // stage 수신, answer는 아직
        vm.cancelStreaming()
        await waitUntilNotStreaming(vm)

        XCTAssertEqual(vm.streamingState, .cancelled)
        let lengthAfterCancel = vm.messages.last?.text.count ?? 0
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(vm.messages.last?.text.count, lengthAfterCancel) // 잔여 작업 없음
    }

    func testReask_whileStreaming_isIgnored() async throws {
        let vm = makeViewModel(eventDelay: .milliseconds(100))
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
        let vm = makeViewModel(eventDelay: .milliseconds(100))
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
