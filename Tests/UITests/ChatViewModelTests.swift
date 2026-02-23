import Testing
import Foundation
@testable import JARVIS

@Suite("ChatViewModel Tests", .serialized)
struct ChatViewModelTests {

    // MARK: - Helpers

    @MainActor
    private func makeViewModel(
        events: [OrchestratorEvent] = [],
        resultText: String = "Response",
        shouldThrow: Error? = nil
    ) -> (ChatViewModel, MockOrchestrator) {
        let mock = MockOrchestrator()
        mock.streamingEvents = events
        mock.processResult = OrchestratorResult(
            text: resultText,
            metrics: TurnMetrics(
                roundCount: 1,
                elapsedTime: 0.1,
                toolsUsed: [],
                errorsEncountered: 0,
                inputTokens: 10,
                outputTokens: 5
            )
        )
        mock.shouldThrow = shouldThrow
        let keychain = MockKeychainHelper()
        let vm = ChatViewModel(orchestrator: mock, keychainHelper: keychain)
        return (vm, mock)
    }

    // MARK: - Test 1: Initial state

    @Test
    @MainActor
    func testInitialState() {
        let (vm, _) = makeViewModel()
        #expect(vm.status == .idle)
        #expect(vm.messages.isEmpty)
        #expect(vm.inputText.isEmpty)
        #expect(vm.needsAPIKey == false)
        #expect(vm.errorMessage == nil)
    }

    // MARK: - Test 2: Empty input does not send

    @Test
    @MainActor
    func testEmptyInputDoesNotSend() async {
        let (vm, mock) = makeViewModel()
        vm.inputText = ""
        vm.send()
        // Give any task a chance to run
        try? await Task.sleep(nanoseconds: 10_000_000)
        #expect(mock.processCallCount == 0)
        #expect(vm.messages.isEmpty)
    }

    // MARK: - Test 3: Whitespace-only input does not send

    @Test
    @MainActor
    func testWhitespaceInputDoesNotSend() async {
        let (vm, mock) = makeViewModel()
        vm.inputText = "   "
        vm.send()
        try? await Task.sleep(nanoseconds: 10_000_000)
        #expect(mock.processCallCount == 0)
        #expect(vm.messages.isEmpty)
    }

    // MARK: - Test 4: Send adds user message

    @Test
    @MainActor
    func testSendAddsUserMessage() async throws {
        let events: [OrchestratorEvent] = [
            .thinkingStarted,
            .textDelta("Hi there"),
            .completed(OrchestratorResult(
                text: "Hi there",
                metrics: TurnMetrics(roundCount: 1, elapsedTime: 0.1, toolsUsed: [], errorsEncountered: 0, inputTokens: 0, outputTokens: 0)
            ))
        ]
        let (vm, _) = makeViewModel(events: events, resultText: "Hi there")
        vm.inputText = "Hello JARVIS"
        vm.send()

        // Wait for async processing
        try await Task.sleep(nanoseconds: 100_000_000)

        // First message should be the user message
        #expect(vm.messages.count >= 1)
        #expect(vm.messages[0].role == .user)
        #expect(vm.messages[0].text == "Hello JARVIS")
    }

    // MARK: - Test 5: Send clears input text

    @Test
    @MainActor
    func testSendClearsInputText() async {
        let (vm, _) = makeViewModel(events: [
            .thinkingStarted,
            .completed(OrchestratorResult(text: "", metrics: TurnMetrics(roundCount: 1, elapsedTime: 0.1, toolsUsed: [], errorsEncountered: 0, inputTokens: 0, outputTokens: 0)))
        ])
        vm.inputText = "Test message"
        vm.send()
        // inputText should be cleared immediately (synchronously)
        #expect(vm.inputText.isEmpty)
    }

    // MARK: - Test 6: Successful text response via streaming

    @Test
    @MainActor
    func testSuccessfulStreamingResponse() async throws {
        let resultText = "Hello, I am JARVIS."
        let events: [OrchestratorEvent] = [
            .thinkingStarted,
            .textDelta("Hello, "),
            .textDelta("I am JARVIS."),
            .completed(OrchestratorResult(
                text: resultText,
                metrics: TurnMetrics(roundCount: 1, elapsedTime: 0.1, toolsUsed: [], errorsEncountered: 0, inputTokens: 10, outputTokens: 5)
            ))
        ]
        let (vm, _) = makeViewModel(events: events, resultText: resultText)
        vm.inputText = "Who are you?"
        vm.send()

        try await Task.sleep(nanoseconds: 200_000_000)

        // Should have user + assistant messages
        #expect(vm.messages.count == 2)
        #expect(vm.messages[0].role == .user)
        #expect(vm.messages[1].role == .assistant)
        #expect(vm.messages[1].text == "Hello, I am JARVIS.")
        #expect(vm.messages[1].isStreaming == false)
        #expect(vm.status == .idle)
    }

    // MARK: - Test 7: Streaming text deltas accumulate

    @Test
    @MainActor
    func testStreamingTextDeltasAccumulate() async throws {
        let events: [OrchestratorEvent] = [
            .thinkingStarted,
            .textDelta("Part1"),
            .textDelta(" Part2"),
            .textDelta(" Part3"),
            .completed(OrchestratorResult(
                text: "Part1 Part2 Part3",
                metrics: TurnMetrics(roundCount: 1, elapsedTime: 0.1, toolsUsed: [], errorsEncountered: 0, inputTokens: 0, outputTokens: 0)
            ))
        ]
        let (vm, _) = makeViewModel(events: events)

        vm.inputText = "Test"
        vm.send()
        try await Task.sleep(nanoseconds: 200_000_000)

        let assistantMsg = vm.messages.first(where: { $0.role == .assistant })
        #expect(assistantMsg?.text == "Part1 Part2 Part3")
    }

    // MARK: - Test 8: Tool execution events

    @Test
    @MainActor
    func testToolExecutionEvents() async throws {
        let events: [OrchestratorEvent] = [
            .thinkingStarted,
            .toolStarted(name: "file_read"),
            .toolCompleted(name: "file_read", result: "file contents", isError: false),
            .textDelta("Here is the file."),
            .completed(OrchestratorResult(
                text: "Here is the file.",
                metrics: TurnMetrics(roundCount: 2, elapsedTime: 0.5, toolsUsed: ["file_read"], errorsEncountered: 0, inputTokens: 0, outputTokens: 0)
            ))
        ]
        let (vm, _) = makeViewModel(events: events, resultText: "Here is the file.")
        vm.inputText = "Read a file"
        vm.send()

        try await Task.sleep(nanoseconds: 200_000_000)

        #expect(vm.status == .idle)
        let assistantMsg = vm.messages.first(where: { $0.role == .assistant })
        #expect(assistantMsg != nil)
        #expect(assistantMsg?.toolCalls.count == 1)
        #expect(assistantMsg?.toolCalls[0].name == "file_read")
        #expect(assistantMsg?.toolCalls[0].status == .completed)
    }

    // MARK: - Test 9: Abort resets status

    @Test
    @MainActor
    func testAbortResetsStatus() async {
        let (vm, mock) = makeViewModel(events: [])
        // Manually set status to simulate in-progress state
        vm.status = .thinking
        // Add an in-progress assistant message
        vm.messages.append(ChatMessage(
            id: UUID(),
            role: .assistant,
            text: "partial",
            timestamp: Date(),
            toolCalls: [],
            isStreaming: true
        ))

        vm.abort()

        #expect(vm.status == .idle)
        #expect(mock.abortCalled == true)
        // Last message should no longer be streaming
        #expect(vm.messages.last?.isStreaming == false)
    }

    // MARK: - Test 10: Confirmation approved

    @Test
    @MainActor
    func testConfirmationApproved() async throws {
        // Test that resolveConfirmation resumes the continuation
        let (vm, _) = makeViewModel()

        // Create a fake pending confirmation via withCheckedContinuation
        var resolvedValue: Bool?
        let confirmTask = Task { @MainActor in
            let result = await vm.requestConfirmation(for: ToolUse(id: "tu-1", name: "dangerous_tool", input: [:]))
            resolvedValue = result
        }

        // Wait briefly for the task to suspend on the continuation
        try await Task.sleep(nanoseconds: 10_000_000)

        // Verify pendingConfirmation is set
        #expect(vm.pendingConfirmation != nil)
        #expect(vm.pendingConfirmation?.toolUse.name == "dangerous_tool")

        // Approve it
        vm.resolveConfirmation(approved: true)

        try await Task.sleep(nanoseconds: 10_000_000)
        _ = await confirmTask.value

        #expect(resolvedValue == true)
        #expect(vm.pendingConfirmation == nil)
    }

    // MARK: - Test 11: Confirmation denied

    @Test
    @MainActor
    func testConfirmationDenied() async throws {
        let (vm, _) = makeViewModel()

        var resolvedValue: Bool?
        let confirmTask = Task { @MainActor in
            let result = await vm.requestConfirmation(for: ToolUse(id: "tu-2", name: "risky_tool", input: [:]))
            resolvedValue = result
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        vm.resolveConfirmation(approved: false)
        try await Task.sleep(nanoseconds: 10_000_000)
        _ = await confirmTask.value

        #expect(resolvedValue == false)
        #expect(vm.pendingConfirmation == nil)
    }

    // MARK: - Test 12: needsAPIKey when no key in keychain

    @Test
    @MainActor
    func testNeedsAPIKeyWhenNoKeyStored() {
        let keychain = MockKeychainHelper()
        keychain.fakeAPIKey = nil
        let vm = ChatViewModel(keychainHelper: keychain)
        #expect(vm.needsAPIKey == true)
    }

    // MARK: - Test 13: saveAPIKey sets needsAPIKey = false

    @Test
    @MainActor
    func testSaveAPIKeyClearsNeedsAPIKey() {
        let keychain = MockKeychainHelper()
        keychain.fakeAPIKey = nil
        let vm = ChatViewModel(keychainHelper: keychain)
        #expect(vm.needsAPIKey == true)
        vm.saveAPIKey("sk-ant-test-key-12345")
        #expect(vm.needsAPIKey == false)
    }
}
