import SwiftUI

/// 최소 스켈레톤 루트 화면.
///
/// 아직 기능 코드는 없다. 종이톤 배경 위에 워드마크만 표시해 앱이 정상 부팅·렌더되는지 확인한다.
/// 디자인 토큰(Core/DesignSystem)·실제 홈 화면(Features/Home)은 이후 커밋에서 대체한다.
struct RootView: View {
    var body: some View {
        ZStack {
            // 앱 화면 베이스 — 따뜻한 종이톤 (#F7F4EE). 정식 토큰은 커밋 3에서 도입.
            Color(red: 0xF7 / 255, green: 0xF4 / 255, blue: 0xEE / 255)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                Text("sttak")
                    .font(.system(size: 40, weight: .bold))
                    .kerning(-1.2)
                    .foregroundStyle(Color(red: 0x26 / 255, green: 0x24 / 255, blue: 0x1F / 255))

                Text("데이터로 시작하는 첫 투자")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(red: 0x8A / 255, green: 0x84 / 255, blue: 0x78 / 255))
            }
        }
    }
}

#Preview {
    RootView()
}
