import Testing
import AppKit
import SwiftUI
@testable import JARVIS

// MARK: - JARVISTheme Tests

@Suite("JARVISTheme Tests")
struct JARVISThemeTests {

    @Test("Color constants are accessible")
    func colorConstantsExist() {
        // Verify NSColor has non-zero components (confirms correct values, not default black)
        let ns = JARVISTheme.nsJarvisBlack
        #expect(ns.blueComponent > 0)   // #080C14 has blue component
        #expect(ns.redComponent > 0)    // has non-zero red too
        // SwiftUI colors just need to be referenceable (compile-time check)
        _ = JARVISTheme.jarvisBlack
        _ = JARVISTheme.jarvisBlue
        _ = JARVISTheme.jarvisCyan
        _ = JARVISTheme.jarvisPurple
        _ = JARVISTheme.jarvisDanger
        _ = JARVISTheme.jarvisBlueDim
        _ = JARVISTheme.jarvisBlue10
        _ = JARVISTheme.jarvisBlue15
        _ = JARVISTheme.jarvisBlue40
        _ = JARVISTheme.jarvisBlue60
    }

    @Test("Font constants are accessible")
    func fontConstantsExist() {
        _ = JARVISTheme.jarvisOutput
        _ = JARVISTheme.jarvisOutputSmall
        _ = JARVISTheme.jarvisUI
        _ = JARVISTheme.jarvisUISmall
        // If we reach here without crashing, fonts exist
        #expect(Bool(true))
    }

    @Test("Animation durations are positive")
    func animationDurationsArePositive() {
        #expect(JARVISTheme.bootSequenceDuration > 0)
        #expect(JARVISTheme.characterRevealInterval > 0)
        #expect(JARVISTheme.bootCharRevealInterval > 0)
        #expect(JARVISTheme.pulsePeriod > 0)
        #expect(JARVISTheme.sonarRingInterval > 0)
    }

    @Test("bootSequenceDuration is approximately 1.8 seconds")
    func bootSequenceDurationIsCorrect() {
        #expect(abs(JARVISTheme.bootSequenceDuration - 1.8) < 0.001)
    }
}

// MARK: - HUDCornerBrackets Tests

@Suite("HUDCornerBrackets Tests")
struct HUDCornerBracketsTests {

    @Test("HUDCornerBrackets modifier instantiates without crash")
    func modifierInstantiates() {
        let modifier = HUDCornerBrackets()
        // If we reach here without crashing, instantiation succeeded
        #expect(modifier.brightness == 1.0)
    }

    @Test("HUDCornerBrackets default parameters match theme constants")
    func defaultParamsMatchTheme() {
        let modifier = HUDCornerBrackets()
        #expect(modifier.armLength == JARVISTheme.cornerBracketArm)
        #expect(modifier.strokeWidth == JARVISTheme.cornerBracketStroke)
        #expect(modifier.brightness == 1.0)
    }
}

// MARK: - ParticleFieldView Tests

@Suite("ParticleFieldView Tests")
struct ParticleFieldViewTests {

    @Test("particleCount constant equals 40")
    func particleCountIs40() {
        #expect(ParticleFieldView.particleCount == 40)
    }

    @Test("makeInitialParticles produces exactly particleCount particles")
    func makeInitialParticlesCount() {
        let particles = ParticleFieldView.makeInitialParticles(
            count: ParticleFieldView.particleCount,
            size: CGSize(width: 400, height: 600)
        )
        #expect(particles.count == ParticleFieldView.particleCount)
    }

    @Test("Particle past right edge wraps to left")
    func wrapRightEdge() {
        let p = ParticleState(x: 401, y: 300, vx: 1, vy: 0)
        let wrapped = ParticleFieldView.wrapped(particle: p, width: 400, height: 600)
        #expect(wrapped.x == 0)
    }

    @Test("Particle past left edge wraps to right")
    func wrapLeftEdge() {
        let p = ParticleState(x: -1, y: 300, vx: -1, vy: 0)
        let wrapped = ParticleFieldView.wrapped(particle: p, width: 400, height: 600)
        #expect(wrapped.x == 400)
    }

    @Test("Particle past bottom edge wraps to top")
    func wrapBottomEdge() {
        let p = ParticleState(x: 200, y: 601, vx: 0, vy: 1)
        let wrapped = ParticleFieldView.wrapped(particle: p, width: 400, height: 600)
        #expect(wrapped.y == 0)
    }

    @Test("Particle past top edge wraps to bottom")
    func wrapTopEdge() {
        let p = ParticleState(x: 200, y: -1, vx: 0, vy: -1)
        let wrapped = ParticleFieldView.wrapped(particle: p, width: 400, height: 600)
        #expect(wrapped.y == 600)
    }

    @Test("Particle within bounds is unchanged")
    func noWrapWhenInBounds() {
        let p = ParticleState(x: 200, y: 300, vx: 0.1, vy: 0.1)
        let wrapped = ParticleFieldView.wrapped(particle: p, width: 400, height: 600)
        #expect(wrapped.x == 200)
        #expect(wrapped.y == 300)
    }
}

// MARK: - BootSequenceController Tests

@Suite("BootSequenceController Tests")
struct BootSequenceControllerTests {

    @Test("BootSequenceController starts in typing phase")
    @MainActor
    func startsInTypingPhase() {
        let controller = BootSequenceController()
        #expect(controller.phase == .typing)
    }

    @Test("BootSequenceController initial typedCount is zero")
    @MainActor
    func initialTypedCountIsZero() {
        let controller = BootSequenceController()
        #expect(controller.typedCount == 0)
    }

    @Test("BootSequenceController phase transitions via direct assignment")
    @MainActor
    func phaseTransitions() {
        let controller = BootSequenceController()
        #expect(controller.phase == .typing)
        controller.phase = .checkmarks(0)
        #expect(controller.phase == .checkmarks(0))
        controller.phase = .checkmarks(1)
        #expect(controller.phase == .checkmarks(1))
        controller.phase = .checkmarks(2)
        #expect(controller.phase == .checkmarks(2))
        controller.phase = .done
        #expect(controller.phase == .done)
    }

    @Test("bootSequenceDuration is within 0.3s of 1.8s")
    func totalDurationApproximately1_8s() {
        #expect(abs(JARVISTheme.bootSequenceDuration - 1.8) < 0.3)
    }
}

// MARK: - StatusDisplayConfig Tests

@Suite("StatusDisplayConfig Tests")
struct StatusDisplayConfigTests {

    @Test("Idle status maps to dimDot")
    func idleMapsToDimDot() {
        #expect(StatusDisplayConfig.from(.idle) == .dimDot)
    }

    @Test("Thinking status maps to spinner with no tool name")
    func thinkingMapsToSpinner() {
        #expect(StatusDisplayConfig.from(.thinking) == .spinner(toolName: nil))
    }

    @Test("ExecutingTool status maps to spinner with tool name")
    func executingMapsToSpinnerWithName() {
        #expect(StatusDisplayConfig.from(.executingTool("calculator")) == .spinner(toolName: "calculator"))
    }

    @Test("Listening status maps to sonar with partial transcript")
    func listeningMapsToSonar() {
        #expect(StatusDisplayConfig.from(.listening("hello")) == .sonar(partial: "hello"))
    }

    @Test("Listening with empty partial maps to sonar with empty string")
    func listeningEmptyMapsToSonar() {
        #expect(StatusDisplayConfig.from(.listening("")) == .sonar(partial: ""))
    }

    @Test("Speaking status maps to equalizer")
    func speakingMapsToEqualizer() {
        #expect(StatusDisplayConfig.from(.speaking) == .equalizer)
    }
}

// MARK: - MessageLayoutConfig Tests

@Suite("MessageLayoutConfig Tests")
struct MessageLayoutConfigTests {

    @Test("User role produces trailing alignment with background, non-monospaced")
    func userRoleLayout() {
        let config = MessageLayoutConfig.from(role: .user)
        #expect(config.alignment == .trailing)
        #expect(config.hasBackground == true)
        #expect(config.isMonospaced == false)
    }

    @Test("Assistant role produces leading alignment, no background, monospaced")
    func assistantRoleLayout() {
        let config = MessageLayoutConfig.from(role: .assistant)
        #expect(config.alignment == .leading)
        #expect(config.hasBackground == false)
        #expect(config.isMonospaced == true)
    }

    @Test("MessageLayoutConfig conforms to Equatable")
    func equatable() {
        let a = MessageLayoutConfig.from(role: .user)
        let b = MessageLayoutConfig.from(role: .user)
        #expect(a == b)
        let c = MessageLayoutConfig.from(role: .assistant)
        #expect(a != c)
    }
}

// MARK: - ToolCallPillState Tests

@Suite("ToolCallPillState Tests")
struct ToolCallPillStateTests {

    @Test("Running status maps to loading pill")
    func runningMapsToLoading() {
        #expect(ToolCallPillState.from(status: .running) == .loading)
    }

    @Test("Completed status maps to checkmark pill")
    func completedMapsToCheckmark() {
        #expect(ToolCallPillState.from(status: .completed) == .checkmark)
    }

    @Test("Failed status maps to failure pill")
    func failedMapsToFailure() {
        #expect(ToolCallPillState.from(status: .failed) == .failure)
    }
}

// MARK: - ChatInputViewState Tests

@Suite("ChatInputViewState Tests")
struct ChatInputViewStateTests {

    @Test("canSend is false when text is empty")
    func canSendFalseWhenEmpty() {
        #expect(ChatInputViewState.canSend(text: "", isEnabled: true, isListening: false) == false)
    }

    @Test("canSend is false when text is only whitespace")
    func canSendFalseWhenWhitespace() {
        #expect(ChatInputViewState.canSend(text: "   ", isEnabled: true, isListening: false) == false)
    }

    @Test("canSend is false when disabled")
    func canSendFalseWhenDisabled() {
        #expect(ChatInputViewState.canSend(text: "hello", isEnabled: false, isListening: false) == false)
    }

    @Test("canSend is false when listening")
    func canSendFalseWhenListening() {
        #expect(ChatInputViewState.canSend(text: "hello", isEnabled: true, isListening: true) == false)
    }

    @Test("canSend is true when enabled with non-empty trimmed text and not listening")
    func canSendTrueWhenValid() {
        #expect(ChatInputViewState.canSend(text: "hello", isEnabled: true, isListening: false) == true)
    }

    @Test("canSend is true when text has leading/trailing whitespace but non-empty content")
    func canSendTrueWithPaddedText() {
        #expect(ChatInputViewState.canSend(text: "  hi  ", isEnabled: true, isListening: false) == true)
    }
}
