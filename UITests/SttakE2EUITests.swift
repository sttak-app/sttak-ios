import XCTest

/// dev 백엔드 대상 라이브 E2E — 개발자 로그인 → 관심종목 선택 → 홈 → 퀴즈 1문항.
/// 실서버(X-User-Id dev 계정)에 실제 요청을 보내므로 네트워크가 필요하다. 시연/검증용.
final class SttakE2EUITests: XCTestCase {

    @MainActor
    func testDevLoginThroughHomeAndQuiz() throws {
        let app = XCUIApplication()
        app.launch()

        // 1) 로그인: dev 폴백 버튼 (이미 로그인된 상태면 건너뜀)
        let devLogin = app.buttons["개발자 로그인"]
        if devLogin.waitForExistence(timeout: 8) {
            devLogin.tap()

            // 2) 온보딩 관심종목: 인기 종목(실서버)에서 두 개 선택 후 시작
            let samsung = app.buttons.containing(
                NSPredicate(format: "label CONTAINS %@", "삼성전자")).firstMatch
            XCTAssertTrue(samsung.waitForExistence(timeout: 15), "관심종목 목록(실서버 인기종목)이 떠야 한다")
            samsung.tap()
            let hynix = app.buttons.containing(
                NSPredicate(format: "label CONTAINS %@", "SK하이닉스")).firstMatch
            if hynix.waitForExistence(timeout: 5) { hynix.tap() }
            snap(app, "onboarding-selected")

            let start = app.buttons.containing(
                NSPredicate(format: "label CONTAINS %@", "담고 시작하기")).firstMatch
            XCTAssertTrue(start.waitForExistence(timeout: 5))
            start.tap()
        }

        // 3) 홈: 탭바가 뜨면 진입 성공 (뉴스는 서버 가공 진행도에 따라 비어 있을 수 있음)
        let quizTab = app.tabBars.buttons["퀴즈"]
        XCTAssertTrue(quizTab.waitForExistence(timeout: 20), "메인 탭바(홈 진입)가 떠야 한다")
        sleep(3) // 홈 데이터 로드 여유
        snap(app, "home")

        // 4) 퀴즈: 서버 출제 → 보기 선택 → 서버 채점 결과 확인
        quizTab.tap()
        let option = app.buttons["quizOption0"]
        if option.waitForExistence(timeout: 15) {
            snap(app, "quiz-question")
            option.tap()
            let confirm = app.buttons.containing(
                NSPredicate(format: "label CONTAINS %@", "정답 확인")).firstMatch
            XCTAssertTrue(confirm.waitForExistence(timeout: 5))
            confirm.tap()
            // 서버 채점 응답(정답/오답 + 해설) 대기
            let graded = app.staticTexts.containing(
                NSPredicate(format: "label IN %@", ["정답", "오답"])).firstMatch
            XCTAssertTrue(graded.waitForExistence(timeout: 15), "서버 채점 결과가 표시돼야 한다")
            sleep(2)
            snap(app, "quiz-graded")
        } else {
            // 쿨다운 등으로 출제가 없으면 화면만 기록
            snap(app, "quiz-state")
        }
    }

    @MainActor
    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
