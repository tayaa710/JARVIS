import Testing
import AppKit
import SwiftUI
@testable import JARVIS

// MARK: - JARVISTheme Tests

@Suite("JARVISTheme Tests")
struct JARVISThemeTests {

    @Test("Color constants are accessible")
    func colorConstantsExist() {
        _ = JARVISTheme.background
        _ = JARVISTheme.surfacePrimary
        _ = JARVISTheme.surfaceSecondary
        _ = JARVISTheme.userBubble
        _ = JARVISTheme.assistantBubble
        _ = JARVISTheme.textPrimary
        _ = JARVISTheme.textSecondary
        _ = JARVISTheme.border
        _ = JARVISTheme.danger
        _ = JARVISTheme.pillBackground
        #expect(Bool(true))
    }

    @Test("AppKit NSColor constant is accessible")
    func nsColorConstantExists() {
        let ns = JARVISTheme.nsBackground
        _ = ns  // referenceable without crash
        #expect(Bool(true))
    }

    @Test("Font constants are accessible")
    func fontConstantsExist() {
        _ = JARVISTheme.body
        _ = JARVISTheme.caption
        _ = JARVISTheme.headline
        // Legacy aliases
        _ = JARVISTheme.jarvisUI
        _ = JARVISTheme.jarvisUISmall
        _ = JARVISTheme.jarvisOutput
        _ = JARVISTheme.jarvisOutputSmall
        #expect(Bool(true))
    }

    @Test("Spacing constants are positive")
    func spacingConstantsArePositive() {
        #expect(JARVISTheme.messagePadding > 0)
        #expect(JARVISTheme.bubbleCornerRadius > 0)
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

    @Test("Assistant role produces leading alignment with background, non-monospaced")
    func assistantRoleLayout() {
        let config = MessageLayoutConfig.from(role: .assistant)
        #expect(config.alignment == .leading)
        #expect(config.hasBackground == true)
        #expect(config.isMonospaced == false)
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
