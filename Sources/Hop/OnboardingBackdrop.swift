import SwiftUI

/// The onboarding's backdrop, tick-driven at 12fps (this codebase uses no
/// `repeatForever`). SPEC: docs/spec.md — "Onboarding".
struct OnboardingBackdrop: View {
    /// Where the light gathers, in unit coordinates.
    var focus: UnitPoint = UnitPoint(x: 0.5, y: 0.3)

    private let spacing: CGFloat = 26
    private let dot: CGFloat = 2.1

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 12.0)) { timeline in
            Canvas { context, size in
                let t: CGFloat = CGFloat(timeline.date.timeIntervalSinceReferenceDate)
                let centre = CGPoint(x: size.width * focus.x, y: size.height * focus.y)
                let reach = max(size.width, size.height) * 0.62
                let base: CGFloat = Theme.isDark ? 0.20 : 0.16
                let ink = Theme.isDark ? Color.white : Color.black

                var y = spacing / 2
                while y < size.height {
                    var x = spacing / 2
                    while x < size.width {
                        let phase: CGFloat = (x + y) / 260 - t / 4.5
                        let counter: CGFloat = (x - y) / 420 + t / 9
                        let wave: CGFloat = (sin(phase) + sin(counter)) / 2
                        let pull: CGFloat = max(0, 1 - hypot(x - centre.x, y - centre.y) / reach)
                        let alpha: CGFloat = base * (0.6 + 0.4 * pull) * (0.75 + 0.25 * wave)
                        if alpha > 0.012 {
                            let d: CGFloat = dot * (0.9 + 0.15 * wave)
                            context.fill(
                                Path(ellipseIn: CGRect(x: x - d / 2, y: y - d / 2, width: d, height: d)),
                                with: .color(ink.opacity(Double(alpha)))
                            )
                        }
                        x += spacing
                    }
                    y += spacing
                }
            }
        }
        .allowsHitTesting(false)
    }
}
