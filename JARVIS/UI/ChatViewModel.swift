import Foundation
import Observation
import AppKit

// MARK: - ChatViewModel

@Observable
@MainActor
final class ChatViewModel {

    // MARK: - System Prompt

    private static let systemPrompt = """
    You are JARVIS, a helpful macOS assistant. You can use tools to help the user with tasks on their \
    computer. Be concise and helpful.
    """

    // MARK: - Published Properties

    var messages: [ChatMessage] = []
    var inputText: String = ""
    var status: AssistantStatus = .idle
    var pendingConfirmation: PendingConfirmation?
    var needsAPIKey: Bool = false
    var errorMessage: String?

    // MARK: - Dependencies

    private let keychainHelper: KeychainHelperProtocol

    // MARK: - Internal State

    private var orchestrator: (any Orchestrator)?
    private var currentTask: Task<Void, Never>?

    // MARK: - Init (production)

    init(keychainHelper: KeychainHelperProtocol = KeychainHelper()) {
        self.keychainHelper = keychainHelper
        if let data = try? keychainHelper.read(key: "anthropic-api-key"),
           let key = String(data: data, encoding: .utf8), !key.isEmpty {
            needsAPIKey = false
            createOrchestrator(apiKey: key)
        } else {
            needsAPIKey = true
        }
    }

    // MARK: - Init (for tests — accepts a pre-built orchestrator)

    init(orchestrator: any Orchestrator, keychainHelper: KeychainHelperProtocol) {
        self.keychainHelper = keychainHelper
        self.orchestrator = orchestrator
        self.needsAPIKey = false
    }

    // MARK: - Public Methods

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, status == .idle, let orch = orchestrator else { return }

        inputText = ""
        messages.append(ChatMessage(
            id: UUID(),
            role: .user,
            text: text,
            timestamp: Date(),
            toolCalls: [],
            isStreaming: false
        ))

        currentTask = Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await orch.processWithStreaming(userMessage: text) { [weak self] event in
                    Task { @MainActor [weak self] in
                        self?.handleEvent(event)
                    }
                }
            } catch OrchestratorError.cancelled {
                await MainActor.run { [weak self] in
                    self?.status = .idle
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.status = .idle
                    self?.errorMessage = error.localizedDescription
                    if let last = self?.messages.last, last.isStreaming {
                        self?.messages[self!.messages.count - 1].isStreaming = false
                    }
                }
            }
        }
    }

    func abort() {
        currentTask?.cancel()
        orchestrator?.abort()
        if let pending = pendingConfirmation {
            pendingConfirmation = nil
            pending.continuation.resume(returning: false)
        }
        if !messages.isEmpty {
            messages[messages.count - 1].isStreaming = false
        }
        status = .idle
    }

    func requestConfirmation(for toolUse: ToolUse) async -> Bool {
        return await withCheckedContinuation { continuation in
            pendingConfirmation = PendingConfirmation(
                id: UUID(),
                toolUse: toolUse,
                continuation: continuation
            )
        }
    }

    func resolveConfirmation(approved: Bool) {
        guard let pending = pendingConfirmation else { return }
        pendingConfirmation = nil
        pending.continuation.resume(returning: approved)
    }

    func saveAPIKey(_ key: String) {
        guard let data = key.data(using: .utf8) else { return }
        do {
            try keychainHelper.save(key: "anthropic-api-key", data: data)
            needsAPIKey = false
            createOrchestrator(apiKey: key)
        } catch {
            errorMessage = "Failed to save API key: \(error.localizedDescription)"
        }
    }

    // MARK: - Private

    private func createOrchestrator(apiKey: String) {
        let registry = ToolRegistryImpl()
        try? registerBuiltInTools(in: registry)

        let policyEngine = PolicyEngineImpl()
        let apiClient = APIClient()
        let modelProvider = AnthropicProvider(apiClient: apiClient, apiKey: apiKey)
        let orch = OrchestratorImpl(
            modelProvider: modelProvider,
            toolRegistry: registry,
            policyEngine: policyEngine,
            systemPrompt: Self.systemPrompt,
            confirmationHandler: { [weak self] toolUse in
                guard let self else { return false }
                return await self.requestConfirmation(for: toolUse)
            }
        )

        // Register AX tools and wire the context lock setter
        let axService = AccessibilityServiceImpl()
        let uiStateCache = UIStateCache()
        let getUIStateTool = try? registerAXTools(
            in: registry,
            accessibilityService: axService,
            cache: uiStateCache
        )
        getUIStateTool?.contextLockSetter = { [weak orch] lock in
            orch?.setContextLock(lock)
        }

        // Register input tools and wire context lock checker
        let inputService = CGEventInputService()
        let lockChecker = ContextLockChecker(
            lockProvider: { [weak orch] in orch?.contextLock },
            appProvider: {
                guard let app = NSWorkspace.shared.frontmostApplication,
                      let bundleId = app.bundleIdentifier else { return nil }
                return (bundleId: bundleId, pid: app.processIdentifier)
            }
        )
        try? registerInputTools(in: registry, inputService: inputService,
                                contextLockChecker: lockChecker, cache: uiStateCache)

        // Register screenshot and vision tools
        let screenshotCache = ScreenshotCache()
        try? registerScreenshotTools(
            in: registry,
            screenshotProvider: SystemScreenshotProvider(),
            cache: screenshotCache,
            modelProvider: modelProvider
        )

        orchestrator = orch
    }

    private func handleEvent(_ event: OrchestratorEvent) {
        switch event {
        case .thinkingStarted:
            status = .thinking
            messages.append(ChatMessage(
                id: UUID(),
                role: .assistant,
                text: "",
                timestamp: Date(),
                toolCalls: [],
                isStreaming: true
            ))

        case .textDelta(let text):
            if !messages.isEmpty && messages[messages.count - 1].role == .assistant {
                messages[messages.count - 1].text += text
            }

        case .toolStarted(let name):
            status = .executingTool(name)
            let toolCall = ToolCallInfo(id: UUID().uuidString, name: name, status: .running, result: nil)
            if !messages.isEmpty && messages[messages.count - 1].role == .assistant {
                messages[messages.count - 1].toolCalls.append(toolCall)
            }

        case .toolCompleted(let name, let result, let isError):
            if !messages.isEmpty && messages[messages.count - 1].role == .assistant {
                let lastIdx = messages.count - 1
                if let toolIdx = messages[lastIdx].toolCalls.firstIndex(where: {
                    $0.name == name && $0.status == .running
                }) {
                    messages[lastIdx].toolCalls[toolIdx].status = isError ? .failed : .completed
                    messages[lastIdx].toolCalls[toolIdx].result = result
                }
            }

        case .completed:
            status = .idle
            if !messages.isEmpty {
                messages[messages.count - 1].isStreaming = false
            }
        }
    }
}
