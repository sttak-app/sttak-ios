import SwiftUI

/// 온보딩(로그인 + 관심종목 선택) 상태를 구동한다.
@MainActor
@Observable
final class OnboardingViewModel {
    // 로그인
    private(set) var isAuthenticating = false
    private(set) var loginError: String?

    // 관심종목 선택
    var query: String = ""
    private(set) var popular: [Stock] = []
    private(set) var searchResults: [Stock] = []
    private(set) var isSearching = false
    private(set) var selectedCodes: [String] = []
    private(set) var quotes: [String: Quote] = [:]
    private(set) var toastMessage: String?
    private(set) var isSaving = false

    private let auth: AuthRepository
    private let marketData: MarketDataRepository
    private var toastTask: Task<Void, Never>?

    init(auth: AuthRepository, marketData: MarketDataRepository) {
        self.auth = auth
        self.marketData = marketData
    }

    // MARK: 파생 상태
    var selectionCount: Int { selectedCodes.count }
    var maxCount: Int { User.maxWatchlistCount }
    var canProceed: Bool { !selectedCodes.isEmpty }      // 핸드오프: 최소 1개
    var isAtCap: Bool { selectedCodes.count >= User.maxWatchlistCount }
    var isSearchActive: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }
    var showsNoResults: Bool { isSearchActive && !isSearching && searchResults.isEmpty }
    var selectedStocks: [Stock] {
        selectedCodes.compactMap { code in stock(for: code) }
    }

    func isSelected(_ code: String) -> Bool { selectedCodes.contains(code) }
    func quote(for code: String) -> Quote? { quotes[code] }

    private func stock(for code: String) -> Stock? {
        popular.first { $0.code == code } ?? searchResults.first { $0.code == code }
    }

    // MARK: 로그인
    /// 소셜 로그인(Mock). 성공 시 true.
    func signIn(with provider: AuthProvider) async -> Bool {
        isAuthenticating = true
        loginError = nil
        defer { isAuthenticating = false }
        do {
            _ = try await auth.signIn(with: provider)
            return true
        } catch {
            loginError = "로그인에 실패했어요. 잠시 후 다시 시도해 주세요."
            return false
        }
    }

    // MARK: 관심종목
    func loadPopular() async {
        guard popular.isEmpty else { return }
        do {
            let stocks = try await marketData.fetchPopularStocks()
            popular = stocks
            await loadQuotes(for: stocks.map(\.code))
        } catch {
            popular = []
        }
    }

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            let results = try await marketData.searchStocks(query: trimmed)
            // 입력이 그 사이 바뀌었으면 버린다.
            guard query.trimmingCharacters(in: .whitespaces) == trimmed else { return }
            searchResults = results
            await loadQuotes(for: results.map(\.code))
        } catch {
            searchResults = []
        }
    }

    func clearSearch() {
        query = ""
        searchResults = []
    }

    func toggle(_ code: String) {
        if let index = selectedCodes.firstIndex(of: code) {
            selectedCodes.remove(at: index)
        } else if isAtCap {
            showToast("최대 \(User.maxWatchlistCount)개까지 담을 수 있어요")
        } else {
            selectedCodes.append(code)
        }
    }

    /// 선택한 관심종목 저장. 성공 시 true → 온보딩 완료.
    func saveWatchlist() async -> Bool {
        guard canProceed else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await auth.updateWatchlist(selectedCodes)
            return true
        } catch {
            showToast("저장에 실패했어요. 다시 시도해 주세요.")
            return false
        }
    }

    // MARK: 내부
    private func loadQuotes(for codes: [String]) async {
        guard !codes.isEmpty else { return }
        if let fetched = try? await marketData.fetchQuotes(forStockCodes: codes) {
            quotes.merge(fetched) { _, new in new }
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            self?.toastMessage = nil
        }
    }
}
