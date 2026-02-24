import Foundation

// Registers all 10 built-in tools into the provided registry.
// Called by AppDelegate at startup and by integration tests.
func registerBuiltInTools(in registry: any ToolRegistry) throws {
    try registry.register(SystemInfoTool())
    try registry.register(AppListTool())
    try registry.register(AppOpenTool())
    try registry.register(FileSearchTool())
    try registry.register(FileReadTool())
    try registry.register(FileWriteTool())
    try registry.register(ClipboardReadTool())
    try registry.register(ClipboardWriteTool())
    try registry.register(WindowListTool())
    try registry.register(WindowManageTool())
}

// Registers the 3 AX tools and returns GetUIStateTool so the caller can wire
// the contextLockSetter closure after the orchestrator is created.
@discardableResult
func registerAXTools(
    in registry: any ToolRegistry,
    accessibilityService: any AccessibilityServiceProtocol,
    cache: UIStateCache
) throws -> GetUIStateTool {
    let getUIState = GetUIStateTool(accessibilityService: accessibilityService, cache: cache)
    try registry.register(getUIState)
    try registry.register(AXActionTool(accessibilityService: accessibilityService, cache: cache))
    try registry.register(AXFindTool(accessibilityService: accessibilityService, cache: cache))
    return getUIState
}

// Registers screenshot and vision_analyze tools.
// modelProvider is the same instance used by the orchestrator (send() is stateless).
func registerScreenshotTools(
    in registry: any ToolRegistry,
    screenshotProvider: any ScreenshotProviding,
    cache: ScreenshotCache,
    modelProvider: any ModelProvider
) throws {
    try registry.register(ScreenshotTool(screenshotProvider: screenshotProvider, cache: cache))
    try registry.register(VisionAnalyzeTool(cache: cache, modelProvider: modelProvider))
}

// Registers the 6 browser tools (browser_navigate, browser_get_url, browser_get_text,
// browser_find_element, browser_click, browser_type).
func registerBrowserTools(in registry: any ToolRegistry, backend: any BrowserBackend) throws {
    try registry.register(BrowserNavigateTool(backend: backend))
    try registry.register(BrowserGetURLTool(backend: backend))
    try registry.register(BrowserGetTextTool(backend: backend))
    try registry.register(BrowserFindElementTool(backend: backend))
    try registry.register(BrowserClickTool(backend: backend))
    try registry.register(BrowserTypeTool(backend: backend))
}

// Registers the 4 input tools (keyboard_type, keyboard_shortcut, mouse_click, mouse_move).
// Called after registerAXTools so the contextLockChecker can reference the orchestrator lock.
func registerInputTools(
    in registry: any ToolRegistry,
    inputService: any InputControlling,
    contextLockChecker: ContextLockChecker,
    cache: UIStateCache
) throws {
    try registry.register(KeyboardTypeTool(inputService: inputService,
                                           contextLockChecker: contextLockChecker,
                                           cache: cache))
    try registry.register(KeyboardShortcutTool(inputService: inputService,
                                               contextLockChecker: contextLockChecker,
                                               cache: cache))
    try registry.register(MouseClickTool(inputService: inputService,
                                         contextLockChecker: contextLockChecker,
                                         cache: cache))
    try registry.register(MouseMoveTool(inputService: inputService))
}
