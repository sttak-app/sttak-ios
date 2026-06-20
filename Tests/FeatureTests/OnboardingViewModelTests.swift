import XCTest
@testable import sttak

/// 온보딩 ViewModel 로직 테스트 — 특히 5개 하드 캡과 저장 연결(시뮬레이터 탭이 불가하므로 결정적 검증).
@MainActor
final class OnboardingViewModelTests: XCTestCase {

    private func makeViewModel(store: MockLocalStore = MockLocalStore()) -> (OnboardingViewModel, MockAuthRepository) {
        let auth = MockAuthRepository(store: store)
        let vm = OnboardingViewModel(auth: auth, marketData: MockMarketDataRepository())
        return (vm, auth)
    }

    func testWatchlistCap_blocksBeyondFive() {
        let (vm, _) = makeViewModel()
        let codes = ["005930", "000660", "035420", "035720", "005380", "000270"]

        for code in codes.prefix(User.maxWatchlistCount) { vm.toggle(code) }
        XCTAssertEqual(vm.selectionCount, 5)
        XCTAssertTrue(vm.isAtCap)
        XCTAssertNil(vm.toastMessage)

        vm.toggle(codes[5]) // 6번째 시도
        XCTAssertEqual(vm.selectionCount, 5)        // 차단됨
        XCTAssertNotNil(vm.toastMessage)            // 안내 토스트
        XCTAssertTrue(vm.canProceed)
    }

    func testToggle_selectsAndDeselects() {
        let (vm, _) = makeViewModel()
        XCTAssertFalse(vm.canProceed)               // 0개 → 비활성
        vm.toggle("005930")
        XCTAssertTrue(vm.isSelected("005930"))
        XCTAssertTrue(vm.canProceed)                // 1개 → 활성
        vm.toggle("005930")                         // 다시 누르면 해제
        XCTAssertFalse(vm.isSelected("005930"))
        XCTAssertFalse(vm.canProceed)
    }

    func testSaveWatchlist_persistsSelectedCodes() async {
        let store = MockLocalStore()
        let (vm, auth) = makeViewModel(store: store)

        let signedIn = await vm.signIn(with: .kakao)
        XCTAssertTrue(signedIn)

        vm.toggle("005930")
        vm.toggle("000660")
        let saved = await vm.saveWatchlist()
        XCTAssertTrue(saved)

        let user = (try? await auth.currentUser()) ?? nil
        XCTAssertEqual(user?.watchlistCodes, ["005930", "000660"])
    }

    func testSaveWatchlist_withNoSelection_returnsFalse() async {
        let (vm, _) = makeViewModel()
        _ = await vm.signIn(with: .kakao)
        let saved = await vm.saveWatchlist()
        XCTAssertFalse(saved)
    }

    func testSearch_filtersByNameOrCode() async {
        let (vm, _) = makeViewModel()
        vm.query = "삼성"
        await vm.search()
        XCTAssertTrue(vm.searchResults.contains { $0.code == "005930" })
        XCTAssertFalse(vm.showsNoResults)

        vm.query = "없는종목명12345"
        await vm.search()
        XCTAssertTrue(vm.searchResults.isEmpty)
        XCTAssertTrue(vm.showsNoResults)
    }
}
