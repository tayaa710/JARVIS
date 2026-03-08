import SwiftUI

// MARK: - HUD Corner Brackets ViewModifier

/// Draws four L-shaped corner brackets on any view, giving it an Iron Man HUD frame.
struct HUDCornerBrackets: ViewModifier {

    var color: Color       = JARVISTheme.jarvisBlue60
    var armLength: CGFloat = JARVISTheme.cornerBracketArm
    var strokeWidth: CGFloat = JARVISTheme.cornerBracketStroke
    var brightness: Double = 1.0

    func body(content: Content) -> some View {
        content.overlay(
            Canvas { ctx, size in
                let w = size.width
                let h = size.height
                let arm = armLength
                let sw  = strokeWidth
                var drawColor = color
                if brightness != 1.0 {
                    drawColor = color.opacity(brightness)
                }
                let resolved = ctx.resolve(Text("").foregroundStyle(drawColor))
                _ = resolved // silence unused warning
                ctx.stroke(
                    cornerPath(w: w, h: h, arm: arm),
                    with: .color(drawColor),
                    lineWidth: sw
                )
            }
        )
    }

    // MARK: - Private

    private func cornerPath(w: CGFloat, h: CGFloat, arm: CGFloat) -> Path {
        var path = Path()
        // Top-left
        path.move(to: CGPoint(x: 0, y: arm))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: arm, y: 0))
        // Top-right
        path.move(to: CGPoint(x: w - arm, y: 0))
        path.addLine(to: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w, y: arm))
        // Bottom-right
        path.move(to: CGPoint(x: w, y: h - arm))
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: w - arm, y: h))
        // Bottom-left
        path.move(to: CGPoint(x: arm, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: 0, y: h - arm))
        return path
    }
}

// MARK: - View Extension

extension View {
    /// Applies the Iron Man HUD corner-bracket frame to the view.
    func hudCornerBrackets(
        color: Color = JARVISTheme.jarvisBlue60,
        armLength: CGFloat = JARVISTheme.cornerBracketArm,
        strokeWidth: CGFloat = JARVISTheme.cornerBracketStroke,
        brightness: Double = 1.0
    ) -> some View {
        modifier(HUDCornerBrackets(
            color: color,
            armLength: armLength,
            strokeWidth: strokeWidth,
            brightness: brightness
        ))
    }
}
