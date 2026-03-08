import SwiftUI
import Observation

// MARK: - Boot Phase

enum BootPhase: Equatable {
    case typing
    case checkmarks(Int)   // 0, 1, 2 = number of checkmarks shown so far
    case done
}

// MARK: - Boot Sequence Controller

/// Drives the boot sequence timing. Extracted from the view so it can be unit-tested.
@Observable
final class BootSequenceController {

    var phase: BootPhase = .typing
    private(set) var typedCount: Int = 0

    private let initLine = "INITIALIZING JARVIS v2.0..."
    private var onComplete: (() -> Void)?

    func start(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        typedCount = 0
        phase = .typing
        typeNextChar()
    }

    // MARK: - Private

    private func typeNextChar() {
        guard typedCount < initLine.count else {
            // Typing done — brief pause then show checkmarks
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                self?.showCheckmarks(index: 0)
            }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + JARVISTheme.bootCharRevealInterval) { [weak self] in
            guard let self else { return }
            typedCount += 1
            typeNextChar()
        }
    }

    private func showCheckmarks(index: Int) {
        let count = 3
        phase = .checkmarks(index)
        guard index < count else {
            // All checkmarks shown — pause then complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.phase = .done
                self?.onComplete?()
            }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            self?.showCheckmarks(index: index + 1)
        }
    }

    // Computed for view convenience
    var typedLine: String {
        String(initLine.prefix(typedCount))
    }
}

// MARK: - Boot Sequence View

struct BootSequenceView: View {

    let onComplete: () -> Void

    @State private var controller = BootSequenceController()

    private let checkmarkLines = [
        "[✓] NEURAL INTERFACE READY",
        "[✓] TOOL REGISTRY LOADED",
        "[✓] VOICE PIPELINE ACTIVE"
    ]

    var body: some View {
        ZStack {
            JARVISTheme.jarvisBlack.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                // Typing line
                Text(controller.typedLine)
                    .font(JARVISTheme.jarvisOutputSmall)
                    .foregroundStyle(JARVISTheme.jarvisCyan)

                // Checkmarks
                ForEach(checkmarkLines.indices, id: \.self) { i in
                    let visible: Bool = {
                        switch controller.phase {
                        case .checkmarks(let n): return i < n
                        case .done: return true
                        default: return false
                        }
                    }()
                    Text(checkmarkLines[i])
                        .font(JARVISTheme.jarvisOutputSmall)
                        .foregroundStyle(JARVISTheme.jarvisBlue)
                        .opacity(visible ? 1 : 0)
                        .animation(.easeIn(duration: 0.15), value: visible)
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            controller.start(onComplete: onComplete)
        }
    }
}
