import Testing
import Foundation
@testable import JARVIS

@Suite("ChatViewModel STT Tests", .serialized)
struct ChatViewModelSTTTests {

    // MARK: - Helpers

    @MainActor
    private func makeViewModel() -> (ChatViewModel, MockSpeechInput, MockOrchestrator) {
        let mockOrchestrator = MockOrchestrator()
        let result = OrchestratorResult(
            text: "OK",
            metrics: TurnMetrics(
                roundCount: 1,
                elapsedTime: 0.1,
                toolsUsed: [],
                errorsEncountered: 0,
                inputTokens: 10,
                outputTokens: 5
            )
        )
        mockOrchestrator.streamingEvents = [.completed(result)]
        mockOrchestrator.processResult = result
        let speechInput = MockSpeechInput()
        let keychain = MockKeychainHelper()
        let vm = ChatViewModel(
            orchestrator: mockOrchestrator,
            keychainHelper: keychain,
            speechInput: speechInput
        )
        return (vm, speechInput, mockOrchestrator)
    }

    // MARK: - Tests

    @Test("startListening sets status to .listening")
    @MainActor
    func testStartListeningSetsStatusToListening() async throws {
        let (vm, _, _) = makeViewModel()
        await vm.startListening()
        #expect(vm.isListeningForSpeech == true)
        if case .listening(let text) = vm.status {
            #expect(text.isEmpty)
        } else {
            Issue.record("Expected .listening status, got \(vm.status)")
        }
        await vm.stopListening()
    }

    @Test("partial transcript updates status and inputText")
    @MainActor
    func testPartialTranscriptUpdatesStatusAndInput() async throws {
        let (vm, speechInput, _) = makeViewModel()
        await vm.startListening()

        speechInput.simulatePartial("open saf")
        try await Task.sleep(nanoseconds: 30_000_000)

        if case .listening(let text) = vm.status {
            #expect(text == "open saf")
        } else {
            Issue.record("Expected .listening with partial, got \(vm.status)")
        }
        #expect(vm.inputText == "open saf")
        await vm.stopListening()
    }

    @Test("final transcript calls send() automatically")
    @MainActor
    func testFinalTranscriptCallsSend() async throws {
        let (vm, speechInput, mockOrchestrator) = makeViewModel()
        await vm.startListening()

        speechInput.simulateFinal("open safari")
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(mockOrchestrator.processCallCount >= 1)
    }

    @Test("stopListening resets status to idle")
    @MainActor
    func testStopListeningResetsStatusToIdle() async throws {
        let (vm, _, _) = makeViewModel()
        await vm.startListening()
        #expect(vm.isListeningForSpeech == true)

        await vm.stopListening()
        #expect(vm.status == .idle)
    }

    @Test("STT error sets errorMessage")
    @MainActor
    func testSTTErrorSetsErrorMessage() async throws {
        let (vm, speechInput, _) = makeViewModel()
        await vm.startListening()

        speechInput.simulateError(SpeechInputError.connectionFailed("Network unreachable"))
        try await Task.sleep(nanoseconds: 30_000_000)

        #expect(vm.errorMessage != nil)
        #expect(vm.status == .idle)
    }

    @Test("toggleListening starts when idle")
    @MainActor
    func testToggleListeningStartsWhenIdle() async throws {
        let (vm, _, _) = makeViewModel()
        #expect(vm.status == .idle)

        vm.toggleListening()
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(vm.isListeningForSpeech == true)
        await vm.stopListening()
    }

    @Test("toggleListening stops when already listening")
    @MainActor
    func testToggleListeningStopsWhenListening() async throws {
        let (vm, _, _) = makeViewModel()
        await vm.startListening()
        #expect(vm.isListeningForSpeech == true)

        vm.toggleListening()
        try await Task.sleep(nanoseconds: 80_000_000)

        #expect(vm.status == .idle)
    }
}
