import SwiftUI

// MARK: - Status Display Config

/// Maps AssistantStatus to a testable display configuration.
enum StatusDisplayConfig: Equatable {
    case dimDot
    case spinner(toolName: String?)
    case sonar(partial: String)
    case equalizer

    static func from(_ status: AssistantStatus) -> StatusDisplayConfig {
        switch status {
        case .idle:                    return .dimDot
        case .thinking:                return .spinner(toolName: nil)
        case .executingTool(let name): return .spinner(toolName: name)
        case .listening(let partial):  return .sonar(partial: partial)
        case .speaking:                return .equalizer
        }
    }
}

// MARK: - Status Indicator View

struct StatusIndicatorView: View {

    let status: AssistantStatus
    let onAbort: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            statusContent
            Spacer()
            if status != .idle {
                abortButton
            }
        }
        .padding(.horizontal, JARVISTheme.messagePadding)
        .padding(.vertical, 6)
    }

    // MARK: - Status Content

    @ViewBuilder
    private var statusContent: some View {
        let config = StatusDisplayConfig.from(status)
        switch config {
        case .dimDot:
            idleDot

        case .spinner(let toolName):
            spinnerView(toolName: toolName)

        case .sonar(let partial):
            sonarView(partial: partial)

        case .equalizer:
            equalizerView
        }
    }

    // MARK: - Idle Dot

    private var idleDot: some View {
        Circle()
            .fill(JARVISTheme.jarvisBlue40)
            .frame(width: 6, height: 6)
    }

    // MARK: - Arc Reactor Spinner

    private func spinnerView(toolName: String?) -> some View {
        HStack(spacing: 6) {
            ArcReactorSpinner()
                .frame(width: 20, height: 20)
            if let name = toolName {
                Text("Running \(name)…")
                    .font(JARVISTheme.jarvisOutputSmall)
                    .foregroundStyle(JARVISTheme.jarvisBlue)
            } else {
                Text("Thinking…")
                    .font(JARVISTheme.jarvisOutputSmall)
                    .foregroundStyle(JARVISTheme.jarvisBlue)
            }
        }
    }

    // MARK: - Sonar Rings (Listening)

    private func sonarView(partial: String) -> some View {
        HStack(spacing: 6) {
            SonarRingsView()
                .frame(width: 36, height: 36)
            Text(partial.isEmpty ? "Listening…" : "\"\(partial)\"")
                .font(JARVISTheme.jarvisOutputSmall)
                .foregroundStyle(JARVISTheme.jarvisCyan)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    // MARK: - Equalizer (Speaking)

    private var equalizerView: some View {
        HStack(spacing: 6) {
            EqualizerView()
                .frame(width: 24, height: 16)
            Text("Speaking…")
                .font(JARVISTheme.jarvisOutputSmall)
                .foregroundStyle(JARVISTheme.jarvisBlue)
        }
    }

    // MARK: - Abort Button

    private var abortButton: some View {
        Button(action: onAbort) {
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(JARVISTheme.jarvisDanger)
        }
        .buttonStyle(.plain)
        .help("Stop")
    }
}

// MARK: - Arc Reactor Spinner

private struct ArcReactorSpinner: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let centre = CGPoint(x: size.width / 2, y: size.height / 2)
                let r1 = size.width / 2 - 1
                let r2 = size.width / 2 - 4
                // Outer arc (CW)
                let start1 = Angle(radians: t.truncatingRemainder(dividingBy: .pi * 2))
                let end1   = start1 + .degrees(270)
                var arc1 = Path()
                arc1.addArc(center: centre, radius: r1, startAngle: start1, endAngle: end1, clockwise: false)
                ctx.stroke(arc1, with: .color(JARVISTheme.jarvisBlue), lineWidth: 1.5)
                // Inner arc (CCW)
                let start2 = Angle(radians: -(t * 1.5).truncatingRemainder(dividingBy: .pi * 2))
                let end2   = start2 + .degrees(210)
                var arc2 = Path()
                arc2.addArc(center: centre, radius: r2, startAngle: start2, endAngle: end2, clockwise: false)
                ctx.stroke(arc2, with: .color(JARVISTheme.jarvisBlueDim), lineWidth: 1)
            }
        }
    }
}

// MARK: - Sonar Rings View

private struct SonarRingsView: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let centre = CGPoint(x: size.width / 2, y: size.height / 2)
                let maxR = size.width / 2
                for i in 0..<3 {
                    let offset = Double(i) * JARVISTheme.sonarRingInterval
                    let phase  = (t - offset).truncatingRemainder(dividingBy: 1.0)
                    let r = phase * maxR
                    let alpha = 1.0 - phase
                    let rect  = CGRect(
                        x: centre.x - r, y: centre.y - r,
                        width: r * 2, height: r * 2
                    )
                    ctx.stroke(
                        Path(ellipseIn: rect),
                        with: .color(JARVISTheme.jarvisCyan.opacity(alpha)),
                        lineWidth: 1
                    )
                }
            }
        }
    }
}

// MARK: - Equalizer View

private struct EqualizerView: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let barCount = 5
                let barW = size.width / CGFloat(barCount) - 1
                for i in 0..<barCount {
                    let freq  = 1.8 + Double(i) * 0.7
                    let phase = t * freq + Double(i) * 0.6
                    let h     = (sin(phase) * 0.4 + 0.6) * size.height
                    let x     = CGFloat(i) * (barW + 1)
                    let rect  = CGRect(x: x, y: size.height - h, width: barW, height: h)
                    ctx.fill(Path(rect), with: .color(JARVISTheme.jarvisBlue))
                }
            }
        }
    }
}
