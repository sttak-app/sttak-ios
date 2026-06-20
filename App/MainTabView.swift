import SwiftUI

/// 인증 후 메인 셸. 핸드오프 확정 4탭(홈·차트학습·퀴즈·마이). 랭킹은 별도 탭이 아니라
/// 마이 안에서 진입한다.
struct MainTabView: View {
    @State private var selection: Tab = .home

    enum Tab: Hashable {
        case home, chart, quiz, my
    }

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("홈", systemImage: "house") }
                .tag(Tab.home)
            ChartLearningView()
                .tabItem { Label("차트학습", systemImage: "chart.xyaxis.line") }
                .tag(Tab.chart)
            QuizView(onGoToChart: { selection = .chart }, onGoToRanking: { selection = .my })
                .tabItem { Label("퀴즈", systemImage: "checkmark.circle") }
                .tag(Tab.quiz)
            MyView()
                .tabItem { Label("마이", systemImage: "person") }
                .tag(Tab.my)
        }
        .tint(AppColor.accent)
    }
}

#if DEBUG
#Preview {
    MainTabView()
}
#endif
