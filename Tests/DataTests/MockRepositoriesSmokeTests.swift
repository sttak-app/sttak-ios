import XCTest
@testable import sttak

/// 상태가 있는 Mock의 가벼운 스모크 테스트(동작하는 앱인지 확인).
/// 풀 ExecuteTrade 도메인 테스트는 커밋 16 예정 — 여기선 cash·holdings·적립의 기본 동작만.
final class MockRepositoriesSmokeTests: XCTestCase {

    private func rationale() -> TradeRationale { TradeRationale(text: "테스트 근거") }

    func testPlaceOrder_mockSettlesImmediatelyFilled() async throws {
        let store = MockLocalStore(cash: 10_000_000)
        await store.debugSetPrice(71_200, for: "005930")
        let portfolio = MockPortfolioRepository(store: store)
        let trade = try await portfolio.placeOrder(
            type: .buy, stockCode: "005930", quantity: 5, rationale: rationale()
        )
        // Mock은 즉시 체결(FILLED) — 체결가·기준·시각이 채워진다.
        XCTAssertEqual(trade.status, .filled)
        XCTAssertEqual(trade.filledPrice?.amount, 71_200)
        XCTAssertEqual(trade.fillBasis, .open)
        XCTAssertNotNil(trade.filledAt)
    }

    func testBuy_reducesCash_andAddsHolding() async throws {
        let store = MockLocalStore(cash: 10_000_000)
        await store.debugSetPrice(71_200, for: "005930")
        let portfolio = MockPortfolioRepository(store: store)

        let trade = try await portfolio.placeOrder(
            type: .buy, stockCode: "005930", quantity: 10, rationale: rationale()
        )
        XCTAssertEqual(trade.type, .buy)

        let p = try await portfolio.fetchPortfolio()
        XCTAssertEqual(p.cash.amount, 10_000_000 - 712_000) // 10 × 71,200
        XCTAssertEqual(p.holdings.count, 1)
        XCTAssertEqual(p.holdings.first?.stockCode, "005930")
        XCTAssertEqual(p.holdings.first?.quantity, 10)
        XCTAssertEqual(p.holdings.first?.averagePrice.amount, 71_200)
    }

    func testSell_reversesCash_andReducesHolding() async throws {
        let store = MockLocalStore(cash: 10_000_000)
        let portfolio = MockPortfolioRepository(store: store)

        await store.debugSetPrice(71_200, for: "005930")
        _ = try await portfolio.placeOrder(type: .buy, stockCode: "005930", quantity: 10, rationale: rationale())
        await store.debugSetPrice(72_000, for: "005930")
        _ = try await portfolio.placeOrder(type: .sell, stockCode: "005930", quantity: 4, rationale: rationale())

        let p = try await portfolio.fetchPortfolio()
        // 10,000,000 − 712,000 + 288,000(4 × 72,000) = 9,576,000
        XCTAssertEqual(p.cash.amount, 9_576_000)
        XCTAssertEqual(p.holdings.first?.quantity, 6)
    }

    func testSell_moreThanHeld_throwsValidation() async throws {
        let store = MockLocalStore(cash: 10_000_000)
        await store.debugSetPrice(71_200, for: "005930")
        let portfolio = MockPortfolioRepository(store: store)
        do {
            _ = try await portfolio.placeOrder(type: .sell, stockCode: "005930", quantity: 1, rationale: rationale())
            XCTFail("보유 수량 부족인데 예외가 발생하지 않았습니다.")
        } catch let error as RepositoryError {
            guard case .validation = error else {
                return XCTFail("validation 에러를 기대했지만 \(error) 발생")
            }
        }
    }

    func testBuy_insufficientCash_throwsValidation() async throws {
        let store = MockLocalStore(cash: 100_000)
        await store.debugSetPrice(71_200, for: "005930")
        let portfolio = MockPortfolioRepository(store: store)
        do {
            _ = try await portfolio.placeOrder(type: .buy, stockCode: "005930", quantity: 10, rationale: rationale())
            XCTFail("현금 부족인데 예외가 발생하지 않았습니다.")
        } catch let error as RepositoryError {
            guard case .validation = error else {
                return XCTFail("validation 에러를 기대했지만 \(error) 발생")
            }
        }
    }

    func testQuizSubmit_creditsCapitalIntoSharedPortfolio() async throws {
        let store = MockLocalStore(cash: 10_000_000)
        let portfolio = MockPortfolioRepository(store: store)
        let quiz = MockQuizRepository(store: store)

        // 문항별 제출(전부 정답) — 서버처럼 submit 시점에 적립.
        for i in 0..<MockData.quizQuestions.count {
            guard case let .question(pending, _, total) = try await quiz.nextQuestion() else {
                return XCTFail("문항 \(i)에서 쿨다운이 반환됨")
            }
            XCTAssertEqual(total, 3)
            let result = try await quiz.submitAnswer(
                quizId: pending.id,
                selectedIndex: MockData.quizQuestions[i].answerIndex
            )
            XCTAssertTrue(result.isCorrect)
        }

        // 자본금이 공유 store의 포트폴리오 현금에 반영 + 쿨다운 기록.
        let p = try await portfolio.fetchPortfolio()
        XCTAssertEqual(p.cash.amount, 10_000_000 + 1_500_000)
        let last = try await quiz.lastCompletion()
        XCTAssertEqual(last?.correctCount, 3)
    }

    func testQuizSubmit_partialCorrect_earnsProportionally() async throws {
        let store = MockLocalStore()
        let quiz = MockQuizRepository(store: store)

        // 첫 문제만 정답, 나머지 오답.
        var earned = 0
        var correctCount = 0
        for i in 0..<MockData.quizQuestions.count {
            guard case let .question(pending, _, _) = try await quiz.nextQuestion() else {
                return XCTFail("문항 \(i)에서 쿨다운이 반환됨")
            }
            let answer = MockData.quizQuestions[i].answerIndex
            let selected = i == 0 ? answer : (answer + 1) % pending.options.count
            let result = try await quiz.submitAnswer(quizId: pending.id, selectedIndex: selected)
            earned += result.earnedCapital.amount
            if result.isCorrect { correctCount += 1 }
        }
        XCTAssertEqual(correctCount, 1)
        XCTAssertEqual(earned, 500_000)
        let last = try await quiz.lastCompletion()
        XCTAssertEqual(last?.correctCount, 1)
        XCTAssertEqual(last?.earnedCapital.amount, 500_000)
    }

    func testAuthSignIn_persistsCurrentUser() async throws {
        let store = MockLocalStore()
        let auth = MockAuthRepository(store: store)
        var current = try await auth.currentUser()
        XCTAssertNil(current)

        let user = try await auth.signIn(with: .kakao)
        XCTAssertEqual(user.authProvider, .kakao)

        current = try await auth.currentUser()
        XCTAssertEqual(current?.id, "mock-user")
        XCTAssertEqual(current?.watchlistCodes.count, 3)
    }
}
