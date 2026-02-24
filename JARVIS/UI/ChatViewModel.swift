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

    ## Web Page Interaction — MANDATORY Escalation Path

    When you need to interact with a web page, follow this order strictly. \
    Do NOT skip steps. Do NOT jump to screenshot.

    Step 1: Use browser_get_text to read the page content. This shows you the text and structure \
    of the page so you can figure out what selectors to use.

    Step 2: Use browser_find_element with CSS selectors to locate elements. If the first selector \
    doesn't work, try variations — different class names, tag types, aria attributes, parent elements. \
    Try at least 3-4 different selectors before giving up. Use browser_get_text output to guide your \
    selector choices.

    Step 3: Use browser_click / browser_type to interact with found elements.

    Step 4: If you know the right URL, use browser_navigate to go there directly. For example, \
    github.com/logout, account settings pages, etc. This is often faster than clicking through menus.

    Step 5: Only after Steps 1-4 have ALL failed, consider screenshot + vision_analyze. This is \
    extremely slow (~10s per call) and mouse_click with pixel coordinates is unreliable. Avoid it.

    NEVER use mouse_click with pixel coordinates for web page elements. It is unreliable because \
    page layout varies and JARVIS's window may overlap the target. Always use browser_click with \
    CSS selectors instead.

    NEVER use screenshot + vision_analyze just because browser_find_element returned "not found" \
    for 1-2 selectors. Instead, call browser_get_text to read the page and figure out better selectors.

    ## Native macOS App Interaction

    1. Use get_ui_state + ax_action to interact with UI elements.
    2. Use keyboard_shortcut for well-known shortcuts (Cmd+C, Cmd+V, Cmd+W, etc.).
    3. screenshot + vision_analyze is a last resort for native apps too.

    ## General Rules

    - Use browser_navigate for URLs. Do NOT type URLs with keyboard_type.
    - If a tool returns an error, try a different approach (different selector, different tool) \
    rather than repeating the same failing call.
    - When unsure about page structure, ALWAYS call browser_get_text first.
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
            },
            sessionLogger: FileSessionLogger()
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

        // Register browser tools
        let browserDetector = BrowserDetector()
        let cdpTransport = URLSessionCDPTransport()
        let cdpDiscovery = CDPDiscoveryImpl()
        let cdpBackend = CDPBackendImpl(transport: cdpTransport, discovery: cdpDiscovery)
        let appleScriptBackend = AppleScriptBackend()
        let browserRouter = BrowserRouter(
            detector: browserDetector,
            cdpBackend: cdpBackend,
            appleScriptBackend: appleScriptBackend
        )
        try? registerBrowserTools(in: registry, backend: browserRouter)

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
