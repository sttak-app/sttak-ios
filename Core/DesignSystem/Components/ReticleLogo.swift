import SwiftUI

// MARK: - ReticleLogo — 브랜드 심볼 "리테클(조준경)" 마크
//
// 정사각 영역의 네 모서리 ㄱ자 브래킷 + 정중앙 점. "데이터로 정확히 조준한다"는 의미.
// 기하 출처: docs/design_handoff `sttak Prototype.dc.html` 스플래시 로고(78px 기준).
//   컨테이너 78 · 브래킷 팔 24 · 두께 4 · 외곽 radius 7 · 중앙 점 17(≈22%).
// 비율로 포팅해 임의 크기로 렌더 가능. (HTML의 4개 코너 div + 중앙 div → Shape 1개 + Circle)
struct ReticleLogo: View {
    /// 로고 한 변 길이(pt).
    var size: CGFloat = 78
    /// 브래킷·중앙 점 색. 기본 브랜드 틸.
    var color: Color = AppColor.accent
    /// 브래킷 선 두께 override. nil이면 size 비례(4/78).
    var lineWidth: CGFloat? = nil

    private var strokeWidth: CGFloat { lineWidth ?? size * (4.0 / 78.0) }
    private var dotDiameter: CGFloat { size * (17.0 / 78.0) }

    var body: some View {
        ReticleBrackets(armRatio: 24.0 / 78.0, cornerRadiusRatio: 7.0 / 78.0, strokeWidth: strokeWidth)
            .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
            .overlay {
                Circle()
                    .fill(color)
                    .frame(width: dotDiameter, height: dotDiameter)
            }
            .frame(width: size, height: size)
            .accessibilityLabel("sttak")
    }
}

/// 네 모서리 ㄱ자 브래킷(외곽 모서리만 둥글게)을 그리는 Shape.
/// 스트로크 중심선 기준으로 그리며, 외곽 모서리는 quad-curve로 둥글린다.
struct ReticleBrackets: Shape {
    var armRatio: CGFloat          // 팔 길이 / 한 변
    var cornerRadiusRatio: CGFloat // 외곽 모서리 반경 / 한 변
    var strokeWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        let half = strokeWidth / 2          // 스트로크가 프레임 안에 들어오도록 inset
        let arm = s * armRatio
        let cr = max(s * cornerRadiusRatio - half, 0) // 중심선 기준 모서리 반경
        let w = rect.width
        let h = rect.height

        var p = Path()

        // 좌상(TL)
        p.move(to: CGPoint(x: arm, y: half))
        p.addLine(to: CGPoint(x: half + cr, y: half))
        p.addQuadCurve(to: CGPoint(x: half, y: half + cr), control: CGPoint(x: half, y: half))
        p.addLine(to: CGPoint(x: half, y: arm))

        // 우상(TR)
        p.move(to: CGPoint(x: w - arm, y: half))
        p.addLine(to: CGPoint(x: w - half - cr, y: half))
        p.addQuadCurve(to: CGPoint(x: w - half, y: half + cr), control: CGPoint(x: w - half, y: half))
        p.addLine(to: CGPoint(x: w - half, y: arm))

        // 좌하(BL)
        p.move(to: CGPoint(x: half, y: h - arm))
        p.addLine(to: CGPoint(x: half, y: h - half - cr))
        p.addQuadCurve(to: CGPoint(x: half + cr, y: h - half), control: CGPoint(x: half, y: h - half))
        p.addLine(to: CGPoint(x: arm, y: h - half))

        // 우하(BR)
        p.move(to: CGPoint(x: w - arm, y: h - half))
        p.addLine(to: CGPoint(x: w - half - cr, y: h - half))
        p.addQuadCurve(to: CGPoint(x: w - half, y: h - half - cr), control: CGPoint(x: w - half, y: h - half))
        p.addLine(to: CGPoint(x: w - half, y: h - arm))

        return p
    }
}

#if DEBUG
#Preview("ReticleLogo") {
    VStack(spacing: 32) {
        ReticleLogo(size: 78)
        ReticleLogo(size: 52)
        ReticleLogo(size: 26)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppColor.backgroundPrimary)
}
#endif
