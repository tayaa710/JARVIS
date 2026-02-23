# JARVIS — Milestones

## How Milestones Work

Each milestone is a small, self-contained unit of work. Every milestone:
- Has clear deliverables (what to build)
- Has test criteria (how to verify it works)
- Ends with passing tests and updated docs
- Can be built in 1-2 coding sessions

Milestones are grouped into phases. Phases must be completed in order. Milestones within a phase should generally be completed in order but some can be parallelised if noted.

**Status key:** `[ ]` = not started, `[~]` = in progress, `[x]` = complete

---

## Phase 0 — Foundation

The skeleton. Nothing works yet, but the project compiles, tests run, and the architecture is in place.

### M001: Project Setup `[x]`

**What to build:**
- New Xcode project (macOS app, SwiftUI lifecycle, bundle ID: com.aidaemon)
- SPM dependencies: Sparkle, KeyboardShortcuts
- Directory structure matching CLAUDE.md spec (App/, Core/, Tools/, Voice/, Memory/, UI/, Shared/, Tests/)
- `.gitignore` (ignore build artifacts, .DS_Store, but track .xcodeproj)
- Empty placeholder files for key protocols (ModelProvider, ToolExecutor, ToolRegistry, PolicyEngine)
- GitHub Actions CI config: build + test on every push

**Test criteria:**
- `xcodebuild build` succeeds with zero warnings ✓
- `xcodebuild test` runs and passes (5 tests, all green) ✓
- GitHub Actions runs successfully on push ✓ (config committed)

**Deliverables:**
- Compiling Xcode project ✓
- CI pipeline running ✓
- All placeholder protocols defined ✓

**Built:**
- `JARVIS/App/JARVISApp.swift` — SwiftUI @main entry point
- `JARVIS/UI/ContentView.swift` — placeholder view (400×300, shows "JARVIS")
- `JARVIS/Core/Types.swift` — stub types: Message, ToolDefinition, Response, StreamEvent, ToolCall, ToolResult, RiskLevel, PolicyDecision
- `JARVIS/Core/ModelProvider.swift` — protocol with send, sendStreaming, abort
- `JARVIS/Core/ToolExecutor.swift` — protocol with definition + execute
- `JARVIS/Core/ToolRegistry.swift` — protocol with register, executor, allDefinitions, validate, dispatch
- `JARVIS/Core/PolicyEngine.swift` — protocol with evaluate
- `JARVIS/Info.plist` — bundle ID com.aidaemon, macOS 14.0 minimum
- `JARVIS/JARVIS.entitlements` — sandbox disabled
- `JARVIS/Resources/Assets.xcassets/` — asset catalog (AccentColor + AppIcon placeholders)
- `project.yml` — xcodegen spec (Sparkle 2.x + KeyboardShortcuts 2.x, macOS 14 target)
- `JARVIS.xcodeproj/` — generated Xcode project (tracked in git)
- `Tests/CoreTests/PlaceholderTests.swift` — 5 tests validating all protocol signatures compile
- `.github/workflows/ci.yml` — build + test on push/PR to main

**Decisions:**
- xcodegen `from: "2.0.0"` syntax (not `majorVersion:`) — xcodegen 2.44.1 uses `from`
- `GENERATE_INFOPLIST_FILE: true` required on test target to satisfy code signing
- Swift 5 mode (not Swift 6) — avoids strict concurrency warnings from Sparkle/KeyboardShortcuts

**Xcode build steps for owner:**
1. Open terminal in repo root: `cd /Users/aarontaylor/JARVIS`
2. Double-click `JARVIS.xcodeproj` to open in Xcode (or `open JARVIS.xcodeproj`)
3. Select the **JARVIS** scheme in the toolbar
4. Press **Cmd+B** to build — should show "Build Succeeded"
5. Press **Cmd+U** to run tests — should show 5 tests passed
6. Press **Cmd+R** to run the app — a window appears saying "JARVIS"

---

### M002: Logging and API Client `[x]`

**What to build:**
- `Logger.swift` — wrapper around `os.log` with subsystems per component. Convenience methods: `Logger.orchestrator.info(...)`, `Logger.tools.error(...)`, etc.
- `APIClient.swift` — generic async HTTP client. Methods: `get`, `post`, `postStreaming`. Handles: timeouts, retry with exponential backoff for 429/5xx, structured error types. All network calls in the app go through this.
- `KeychainHelper.swift` — read/write/delete secrets from macOS Keychain.

**Test criteria:**
- Logger: verify log output contains correct subsystem and level (unit test with mock log handler) ✓
- APIClient: test request building, header injection, timeout behavior, retry logic (unit tests with mock URLProtocol) ✓
- APIClient: test streaming response parsing ✓
- KeychainHelper: write, read, delete, overwrite (integration test against real Keychain) ✓

**Deliverables:**
- All three utilities with full test coverage ✓
- No `NSLog` or `print` statements anywhere — only Logger ✓

**Built:**
- `JARVIS/Shared/Logger.swift` — `LogLevel` enum, `LogHandler` protocol, `OSLogHandler` (production), `JARVISLogger` struct, `Logger` namespace enum with 9 pre-configured loggers (orchestrator, tools, api, policy, voice, memory, ui, keychain, app)
- `JARVIS/Shared/KeychainHelper.swift` — `KeychainHelperProtocol`, `KeychainError` enum, `KeychainHelper` struct wrapping Security.framework with save/read/delete + String convenience overloads
- `JARVIS/Shared/APIClient.swift` — `APIClientError` enum, `APIClientProtocol`, `APIClient` with get/post/postStreaming, exponential backoff retry on 429/5xx, Retry-After header support, URLSessionConfiguration injection for testing
- `Tests/CoreTests/LoggerTests.swift` — 6 tests
- `Tests/CoreTests/KeychainHelperTests.swift` — 6 tests (real Keychain, isolated to "com.aidaemon.test" service)
- `Tests/CoreTests/APIClientTests.swift` — 11 tests (MockURLProtocol, serialized to avoid static state races)

**Total tests: 28 (was 5, added 23)**

**Decisions:**
- `enum Logger` intentionally shadows `os.Logger` within the JARVIS module. Use `os.Logger` inside Logger.swift itself. External callers get the clean `Logger.orchestrator.info(...)` API.
- `APIClient.postStreaming` returns raw `AsyncThrowingStream<Data, Error>` — SSE parsing will be done in `AnthropicProvider` (M003), not here.
- Retry-After header is respected on 429; falls back to exponential backoff if absent.
- `@Suite(.serialized)` on APIClientTests because `MockURLProtocol` uses static state — parallel execution caused races.
- KeychainHelper tests use `service: "com.aidaemon.test"` + UUID keys so they never pollute real app Keychain entries.

**Xcode build steps for owner:**
1. Open terminal: `cd /Users/aarontaylor/JARVIS`
2. Open project: `open JARVIS.xcodeproj`
3. Press **Cmd+B** — "Build Succeeded"
4. Press **Cmd+U** — 28 tests, all green
5. No new UI to verify — these are infrastructure utilities

---

### M003: Model Provider `[x]`

**What to build:**
- `ModelProvider` protocol: `send(messages:tools:system:)`, `sendStreaming(messages:tools:system:)`, `abort()`
- `AnthropicProvider` — implements ModelProvider using Claude Messages API via APIClient
- `MockModelProvider` — returns pre-recorded responses from JSON fixtures for testing
- `Message`, `Response`, `ToolUse`, `ToolResult` data types
- Support for streaming responses (AsyncThrowingStream of text chunks and tool_use blocks)

**Test criteria:**
- AnthropicProvider: test request format matches Anthropic API spec (mock URLProtocol, inspect request body) ✓
- AnthropicProvider: test response parsing for text, tool_use, and mixed responses ✓
- AnthropicProvider: test error handling (401 unauthorized, 429 rate limit, 500 server error) ✓
- AnthropicProvider: test abort cancels in-flight request ✓
- AnthropicProvider: test streaming response parsing ✓
- MockModelProvider: test it returns queued responses in order ✓

**Deliverables:**
- Working Claude API integration (text + tool_use + streaming) ✓
- Mock provider ready for all future integration tests ✓
- JSON fixture files for common response types ✓

**Built:**
- `JARVIS/Shared/JSONValue.swift` — Recursive `JSONValue` enum (string, number, bool, null, array, object). Sendable, Codable, Equatable. Used for tool input schemas and tool_use.input.
- `JARVIS/Core/Types.swift` — Full rewrite: `Role`, `Message` (custom Codable with string shorthand), `ContentBlock` (discriminated union), `ToolUse`, `ToolResult`, `ToolDefinition`, `Response`, `StopReason`, `Usage`, `StreamEvent`. Removed `ToolCall` (renamed to `ToolUse`).
- `JARVIS/Core/ModelProvider.swift` — Updated protocol with `system: String?` param and `AsyncThrowingStream` return type.
- `JARVIS/Core/SSEParser.swift` — `SSEParser` struct that converts raw `AsyncThrowingStream<Data>` into `AsyncThrowingStream<SSEEvent>`. Handles partial chunks, CRLF, comments, no-trailing-newline flush.
- `JARVIS/Core/AnthropicProvider.swift` — `AnthropicError` enum + `AnthropicProvider` final class. Builds Anthropic API requests, maps SSE events to StreamEvent cases, accumulates input_json_delta. NSLock-protected cancel token for synchronous `abort()`. Logs every request and response via `Logger.api`.
- `Tests/Helpers/MockAPIClient.swift` — Queued responses, captured requests, `blockPost` flag for abort tests.
- `Tests/Helpers/MockModelProvider.swift` — Queued responses + streams, call count, recorded args, abort flag. FIFO dequeue. fatalError on empty queue (developer error).
- `Tests/Helpers/TestFixtures.swift` — Loads fixtures from `Tests/Fixtures/` using `#file` path.
- `Tests/Fixtures/text_response.json`, `tool_use_response.json`, `mixed_response.json`, `error_response.json` — API response fixtures.
- `Tests/Fixtures/streaming_text.txt`, `streaming_tool_use.txt` — SSE stream fixtures.
- `Tests/CoreTests/TypesTests.swift` — 11 tests: Codable round-trips, API format correctness.
- `Tests/CoreTests/SSEParserTests.swift` — 6 tests: single event, multiple events, ping, partial chunks, no-trailing-newline, comments.
- `Tests/CoreTests/AnthropicProviderTests.swift` — 15 tests: request format, response parsing, error handling, abort, streaming.
- `Tests/CoreTests/MockModelProviderTests.swift` — 6 tests: FIFO order, recorded args, call count, abort flag, streaming.

**Total tests: 67 (was 28, added 39)**

**Decisions:**
- `JSONValue` bool check before number check — Swift decodes JSON `true`/`false` as `Double` if tried first.
- `Message` encodes single-text-block content as string shorthand; always decodes both forms.
- `AsyncThrowingStream` (not `AsyncStream`) for `sendStreaming` — mid-stream errors (network drop, malformed SSE) must be deliverable.
- `system: String?` added to both protocol methods — Anthropic API takes it as a top-level parameter, not a message.
- `AnthropicProvider` is `final class @unchecked Sendable` with NSLock — `abort()` must be synchronous.
- Cancel token stored as `(() -> Void)?` closure — simpler than type-erasing `Task<T, E>`.
- `SSEParser` handles no-trailing-newline by processing remaining buffer content after stream ends.
- `xcodegen generate` needed after adding new source files — run it whenever new files are added.

**Xcode build steps for owner:**
1. Open terminal: `cd /Users/aarontaylor/JARVIS`
2. Open project: `open JARVIS.xcodeproj`
3. Press **Cmd+B** — "Build Succeeded"
4. Press **Cmd+U** — 67 tests, all green
5. No new UI — these are infrastructure components

---

## Phase 1 — Core Agent Loop

The brain comes alive. JARVIS can think and use tools, but only simple ones.

### M004: Tool System `[x]`

**What to build:**
- `ToolDefinition` — schema for a tool: id, name, description, parameters (type, required, enum values), risk level
- `ToolExecutor` protocol: `execute(arguments:) async throws -> ToolResult`
- `ToolRegistry` — register tools, validate calls against schema, dispatch to executors
- Convert registered tools to Anthropic API format (the JSON schema Claude expects)
- First built-in tool: `system_info` (returns macOS version, hostname, username, disk space, memory — all safe, read-only)

**Test criteria:**
- ToolDefinition: test serialisation to Anthropic JSON format ✓
- ToolRegistry: test registration, lookup, duplicate ID rejection ✓
- ToolRegistry: test argument validation (missing required args, wrong types, invalid enum values) ✓
- ToolRegistry: test dispatch calls correct executor ✓
- system_info tool: test it returns valid data in expected format ✓

**Deliverables:**
- Complete tool infrastructure ✓
- One working tool (system_info) ✓
- Full test coverage ✓

**Built:**
- `JARVIS/Core/ToolExecutor.swift` — Updated protocol: added `riskLevel: RiskLevel`, changed arg type from `[String: String]` to `[String: JSONValue]`, added `id: String` parameter to `execute`
- `JARVIS/Core/ToolRegistry.swift` — Added `ToolRegistryError` enum (`duplicateToolName`, `unknownTool`, `validationFailed`) — Equatable for test assertions
- `JARVIS/Core/SchemaValidator.swift` — Stateless `SchemaValidator` enum with `validate(input:against:)`. Validates required fields, type checks (string/number/integer/boolean/object/array), enum values. Flat schema only — no $ref or nested validation needed for current tools.
- `JARVIS/Core/ToolRegistryImpl.swift` — `final class ToolRegistryImpl: ToolRegistry, @unchecked Sendable`. NSLock-protected `[String: any ToolExecutor]` store. `dispatch` catches executor errors and wraps them in `ToolResult(isError: true)` so Orchestrator always gets a result to send back to Claude.
- `JARVIS/Tools/BuiltIn/SystemInfoTool.swift` — First built-in tool. Read-only: OS version, hostname, username, disk space (GB), RAM (GB). Risk level: `.safe`.
- `Tests/CoreTests/SchemaValidatorTests.swift` — 13 tests
- `Tests/CoreTests/ToolRegistryTests.swift` — 13 tests (includes `StubToolExecutor` helper)
- `Tests/ToolTests/SystemInfoToolTests.swift` — 9 tests

**Total tests: 102 (was 67, added 35)**

**Decisions:**
- `riskLevel` lives on `ToolExecutor`, not `ToolDefinition` — `ToolDefinition` is Codable for the Anthropic API which has no risk concept; risk is an internal concern.
- `execute(id:arguments:)` includes the `id: String` parameter — executors need the `toolUseId` to construct a proper `ToolResult`. Returning just a content string would prevent executors from setting `isError: true` themselves.
- `SchemaValidator` validates flat schemas only — full JSON Schema (allOf/anyOf/$ref/patterns) is not needed for JARVIS's built-in tools. Can be extended later.
- `dispatch` calls `validate` first (which throws typed errors), then re-fetches the executor. Two lock acquisitions is acceptable — tools are registered at startup, making post-validate races effectively impossible.
- `ToolRegistryError.validationFailed` uses `String(describing:)` on the underlying `SchemaValidationError` to include structured field information in the message.

**Xcode build steps for owner:**
1. Open terminal: `cd /Users/aarontaylor/JARVIS`
2. Open project: `open JARVIS.xcodeproj`
3. Press **Cmd+B** — "Build Succeeded"
4. Press **Cmd+U** — 102 tests, all green
5. No new UI — these are infrastructure components

---

### M005: Policy Engine `[x]`

**What to build:**
- `PolicyEngine` — evaluates tool calls against safety rules
- Risk levels: safe, caution, dangerous, destructive
- Autonomy levels: Level 0 (ask all), Level 1 (smart default), Level 2 (full auto)
- Decision matrix: risk level x autonomy level -> allow / requireConfirmation / deny
- Input sanitisation: strip control characters, block path traversal, block system paths, enforce length limits
- Destructive actions ALWAYS require confirmation regardless of autonomy level

**Test criteria:**
- Test every cell in the decision matrix (3 autonomy levels x 4 risk levels = 12 test cases) ✓
- Test path traversal blocking: `../`, `/../`, `..\\`, case-insensitive ✓
- Test system path blocking: `/System`, `/Library`, `/usr`, `/bin`, `/sbin`, `/private` ✓
- Test control character stripping ✓
- Test length limit enforcement ✓
- Test destructive always confirms even at Level 2 ✓

**Deliverables:**
- PolicyEngine with full test coverage ✓
- Clear documentation of the decision matrix ✓

**Built:**
- `JARVIS/Core/Types.swift` — Added `AutonomyLevel` enum (Int raw values 0–2, Sendable+Equatable). Also added `Equatable` to `RiskLevel` and `PolicyDecision` (needed for decision matrix comparisons and test assertions).
- `JARVIS/Core/InputSanitizer.swift` — Stateless `InputSanitizer` enum with `check(call:) -> [SanitizationViolation]`. Checks: path traversal (`../`, `..\`), system paths (`/system/`, `/library/`, `/usr/`, `/bin/`, `/sbin/`, `/private/`, case-insensitive), control characters (ASCII 0–31 except `\t`, `\n`, `\r`), and length > 10,000 chars. Walks nested objects and arrays recursively.
- `JARVIS/Core/PolicyEngineImpl.swift` — `final class PolicyEngineImpl: PolicyEngine, @unchecked Sendable`. NSLock-protected `autonomyLevel`. `init(autonomyLevel: .smartDefault)`. `setAutonomyLevel(_:)` for runtime changes. `evaluate()` runs sanitization first (returns `.deny` on any violation), then applies the decision matrix. Logs via `Logger.policy`.
- `Tests/CoreTests/InputSanitizerTests.swift` — 17 tests covering all sanitization rules
- `Tests/CoreTests/PolicyEngineTests.swift` — 18 tests: 12 decision matrix cells, 5 sanitization integration, 1 autonomy level change

**Total tests: 137 (was 102, added 35)**

**Decision matrix:**

| Risk \ Autonomy | Level 0 (askAll) | Level 1 (smartDefault) | Level 2 (fullAuto) |
|---|---|---|---|
| safe | allow | allow | allow |
| caution | requireConfirmation | allow | allow |
| dangerous | requireConfirmation | requireConfirmation | allow |
| destructive | requireConfirmation | requireConfirmation | requireConfirmation |

**Key rule:** `destructive` ALWAYS requires confirmation, even at Level 2.

**Decisions:**
- `SanitizationViolation` is a plain enum (no `Equatable`) — tests use pattern matching via `contains { if case .foo = $0 { return true }; return false }`.
- System path check uses a trailing-slash prefix list (e.g. `/system/`) so `/binary` is not blocked but `/bin/sh` is.
- `~/Library/...` is NOT blocked — only absolute `/Library/...` paths are blocked.
- `..` alone does NOT trigger path traversal — only `../` and `..\` do.
- `InputSanitizer` is separate from `PolicyEngineImpl` (independently testable, stateless).

**Xcode build steps for owner:**
1. Open terminal: `cd /Users/aarontaylor/JARVIS`
2. Open project: `open JARVIS.xcodeproj`
3. Press **Cmd+B** — "Build Succeeded"
4. Press **Cmd+U** — 137 tests, all green
5. No new UI — these are infrastructure components

---

### M006: Orchestrator `[ ]`

**What to build:**
- `Orchestrator` — the main conversation loop
- Takes user input, builds message payload, sends to Claude, processes response
- Handles tool_use responses: validate via ToolRegistry, check via PolicyEngine, execute, send results back
- Handles end_turn responses: return final text
- Dynamic round limits based on task complexity (Claude self-classifies)
- Timeout enforcement
- Abort/kill switch support (Task cancellation)
- Context lock tracking (which app are we working with)
- Structured logging of every step (tool call, arguments, result, timing)
- Turn metrics: round count, elapsed time, tools used, errors encountered

**Test criteria:**
- Test simple flow: user message -> Claude text response -> done (using MockModelProvider)
- Test tool flow: user message -> Claude tool_use -> execute -> tool_result -> Claude text -> done
- Test multi-round: 3+ rounds of tool use before final answer
- Test max round limit enforcement (stops at limit, returns partial progress)
- Test timeout enforcement
- Test abort cancellation (mid-loop cancel returns immediately)
- Test policy engine integration (dangerous tool triggers confirmation callback)
- Test context lock (set on get_ui_state, verified before input tools)
- Test error handling: tool execution failure -> error sent as tool_result -> Claude adapts
- Record a real Claude API session and replay it as a fixture test

**Deliverables:**
- Working orchestrator with full test coverage
- At least 3 recorded fixture tests (simple query, single tool, multi-tool)
- This is the single most important component — it must be rock solid

---

### M007: Basic Built-in Tools `[ ]`

**What to build:**
- `app_open` — launch an app by name (NSWorkspace)
- `app_list` — list running apps (NSWorkspace)
- `file_search` — find files by name/pattern (FileManager recursive search)
- `file_read` — read file contents (with size limit and path validation)
- `file_write` — write/create files (caution level, path validated)
- `clipboard_read` — get clipboard contents (NSPasteboard)
- `clipboard_write` — set clipboard contents (NSPasteboard)
- `window_list` — list open windows (CGWindowListCopyWindowInfo)
- `window_manage` — move, resize, minimise, close windows

**Test criteria:**
- Each tool: test with valid arguments returns expected result format
- Each tool: test with invalid arguments returns clear error
- Each tool: test risk level is correctly assigned
- file_read: test path validation blocks `../` and system paths
- file_write: test path validation, test creates parent directories
- app_open: test with known app name
- Integration test: MockModelProvider returns tool_use for app_open -> Orchestrator executes -> result sent back

**Deliverables:**
- 9 working tools, all tested
- Integration test proving the full loop works with real tools

---

### M008: Chat UI `[ ]`

**What to build:**
- `FloatingWindow` — always-on-top window, draggable, resizable, can be minimised to menu bar
- `ChatView` — message list showing user messages and JARVIS responses. Support markdown rendering.
- Text input field with send button and Cmd+Enter shortcut
- Status indicator: idle, thinking, executing tool, speaking
- Streaming display: show Claude's response as it arrives, word by word
- Kill switch button (red, always visible during execution)
- Menu bar icon with dropdown: show/hide window, settings, quit
- `ConfirmationDialog` — modal shown when PolicyEngine requires confirmation. Shows: what tool, what arguments, allow/deny buttons.

**Test criteria:**
- FloatingWindow: verify it stays on top, can be hidden/shown via menu bar
- ChatView: verify messages display in correct order
- ChatView: verify streaming text appears incrementally
- Kill switch: verify it calls Orchestrator.abort() and UI resets to idle
- ConfirmationDialog: verify it blocks execution until user responds

**Deliverables:**
- Functional chat interface
- Users can talk to JARVIS via text and see responses
- Kill switch works

---

## Phase 2 — Computer Control

JARVIS can see and interact with any app on the Mac.

### M009: Accessibility Service `[ ]`

**What to build:**
- `AccessibilityService` — wraps macOS AXUIElement API
- `checkPermission()` — verify accessibility access is granted, prompt if not
- `walkFrontmostApp()` — traverse the AX tree of the frontmost app, return structured snapshot
- Element ref map: assign @e1, @e2, etc. to each discovered element
- Depth and element count limits (max 5 levels deep, max 300 elements)
- Thread-safe: all AX calls on a dedicated serial DispatchQueue
- Element snapshot: captures role, title, value, enabled state, position, size for each element

**Test criteria:**
- Permission check: test returns false when not granted (mock AXIsProcessTrusted)
- Tree walking: test with mock AX elements (create fake tree, verify snapshot output)
- Element ref assignment: test refs are sequential and reset between snapshots
- Depth limit: test stops at max depth
- Element count limit: test stops at max count
- Thread safety: test concurrent access doesn't crash

**Deliverables:**
- AccessibilityService with full test coverage
- Note: actual AX interaction requires Accessibility permission. CI tests use mocked AX elements. Manual verification on real Mac confirms real AX works.

---

### M010: UI State and AX Tools `[ ]`

**What to build:**
- `get_ui_state` tool — calls AccessibilityService, returns formatted text snapshot of frontmost app
- `ax_action` tool — performs action on element by ref: press, set_value, focus, show_menu, raise
- `ax_find` tool — search for elements by role, title, or value (substring match)
- Cache: `get_ui_state` result cached for 0.5 seconds, invalidated after any `ax_action`
- Set context lock when `get_ui_state` runs (record bundle ID + PID)

**Test criteria:**
- get_ui_state: test returns formatted snapshot with @e refs
- ax_action press: test calls AXUIElementPerformAction on correct element
- ax_action set_value: test sets value on correct element
- ax_find: test finds elements matching role, title, value criteria
- Cache: test second call within 0.5s returns cached result
- Cache: test ax_action invalidates cache
- Context lock: test lock is set after get_ui_state
- Integration: MockModelProvider scenario where Claude uses get_ui_state then ax_action

**Deliverables:**
- 3 AX tools, fully tested
- Context lock working
- JARVIS can now read and interact with any Mac app that supports AX

---

### M011: Keyboard and Mouse Control `[ ]`

**What to build:**
- `keyboard_type` tool — type text string via CGEvent key events
- `keyboard_shortcut` tool — press key combos like Cmd+C, Cmd+V, Cmd+Tab
- `mouse_click` tool — click at specific coordinates via CGEvent
- `mouse_move` tool — move mouse to coordinates
- All tools verify context lock before executing (refuse if target app changed)
- 200ms delay after execution to let the OS process the event

**Test criteria:**
- keyboard_type: test generates correct CGEvent sequence for given text
- keyboard_shortcut: test parses modifier+key combos correctly (Cmd+C, Ctrl+Shift+A)
- mouse_click: test generates click event at correct coordinates
- Context lock: test all tools refuse when lock check fails
- Integration: fixture test where Claude uses keyboard_shortcut after get_ui_state

**Deliverables:**
- 4 input tools, fully tested
- These are fallback tools — Claude should prefer ax_action when possible

---

### M012: Screenshot and Vision Fallback `[ ]`

**What to build:**
- `screenshot` tool — capture screen or specific window via CGWindowListCreateImage
- `vision_analyze` tool — send screenshot to Claude with a question ("where is the Submit button?"), parse response for coordinates or information
- Screen Recording permission check and prompt
- This is the LAST RESORT fallback. The system prompt must instruct Claude to try AX tools first.

**Test criteria:**
- screenshot: test captures image data (mock CGWindowList for CI)
- vision_analyze: test sends image to Claude vision API and parses coordinate response
- vision_analyze: test handles malformed response gracefully
- Permission check: test returns false when not granted

**Deliverables:**
- Screenshot + vision fallback working
- Clearly documented as last-resort path
- System prompt explicitly prioritises AX over vision

---

## Phase 3 — Browser Control

JARVIS can browse the web and interact with websites.

### M013: Browser Detection `[ ]`

**What to build:**
- `BrowserDetector` — identify frontmost browser app and its type
- Supported types: chromium (Chrome, Edge, Arc, Brave, Vivaldi), safari, firefox, unknown
- Detection via bundle ID matching against known browser bundle IDs
- Return: browser name, bundle ID, type, PID

**Test criteria:**
- Test correct type for each known browser bundle ID
- Test unknown browser returns type "unknown"
- Test with no browser running returns nil

**Deliverables:**
- BrowserDetector, fully tested

---

### M014: CDP Backend (Chrome-family) `[ ]`

**What to build:**
- `CDPBackend` — connect to Chrome DevTools Protocol via WebSocket
- Auto-discover CDP WebSocket URL from Chrome's debug port
- Commands: navigate, evaluate JavaScript, find element (via CSS selector), click element, type in element, get text, get URL
- Connection lifecycle: connect, send command, receive response, disconnect
- Timeout handling per command (10 second default)

**Test criteria:**
- Test WebSocket connection to mock CDP server
- Test each command sends correct CDP JSON and parses response
- Test timeout triggers error after 10 seconds
- Test connection failure returns clear error

**Deliverables:**
- CDP backend for Chrome-family browsers, fully tested

---

### M015: AppleScript Backend (Safari) + Browser Tools `[ ]`

**What to build:**
- `AppleScriptBackend` — control Safari via NSAppleScript
- Commands: navigate to URL, get current URL, get page text, run JavaScript
- `BrowserToolExecutor` — unified tool executor that routes to correct backend based on BrowserDetector
- Browser tools (all route through BrowserToolExecutor):
  - `browser_navigate` — go to URL
  - `browser_get_url` — get current URL
  - `browser_get_text` — get page text content
  - `browser_find_element` — find element by CSS selector or text
  - `browser_click` — click an element
  - `browser_type` — type into an element

**Test criteria:**
- AppleScript: test correct AppleScript generated for each command
- BrowserToolExecutor: test routes to CDP for Chrome, AppleScript for Safari
- Each browser tool: test with valid and invalid arguments
- Integration: fixture test where Claude navigates and interacts with a page

**Deliverables:**
- Safari support
- 6 unified browser tools
- Browser control complete

---

## Phase 4 — Voice Interface

JARVIS can hear you and talk back.

### M016: Wake Word Detection `[ ]`

**What to build:**
- `WakeWordDetector` — integrates Picovoice Porcupine SDK
- Always-listening mode (microphone, <1% CPU)
- Configurable wake phrase (default: "Hey JARVIS")
- Callbacks: onWakeWordDetected, onError
- Start/stop/pause methods
- Microphone permission check and prompt
- Settings UI: enable/disable, change wake phrase

**Test criteria:**
- Test start/stop/pause lifecycle
- Test permission check
- Test callback fires (mock Porcupine)
- Test CPU usage stays under 2% during listen mode

**Deliverables:**
- Working wake word detection
- Settings integration

---

### M017: Speech-to-Text (Deepgram) `[ ]`

**What to build:**
- `SpeechInput` — streaming STT via Deepgram WebSocket API
- Start recording → stream audio chunks → receive partial transcripts → receive final transcript
- Visual feedback: show partial transcript in UI as user speaks
- Silence detection: auto-stop after 2 seconds of silence
- Deepgram API key from Keychain
- Fallback: Apple SFSpeechRecognizer when offline or Deepgram unavailable

**Test criteria:**
- Test WebSocket connection to Deepgram (mock server)
- Test audio streaming sends correct format
- Test partial transcript callback fires
- Test final transcript callback fires
- Test silence detection triggers stop
- Test fallback to Apple Speech when Deepgram fails

**Deliverables:**
- Working streaming STT
- Offline fallback
- Visual feedback during speech

---

### M018: Text-to-Speech (Deepgram) `[ ]`

**What to build:**
- `SpeechOutput` — streaming TTS via Deepgram API
- Accept text chunks (for streaming from Claude's response)
- Queue and play audio seamlessly as chunks arrive
- Voice selection in settings
- Fallback: Apple AVSpeechSynthesizer when offline
- Interrupt: stop speaking immediately when user starts talking or presses kill switch

**Test criteria:**
- Test text-to-audio conversion (mock Deepgram API)
- Test streaming: multiple chunks play back-to-back without gaps
- Test interrupt stops audio immediately
- Test fallback to Apple TTS
- Test voice selection changes output

**Deliverables:**
- Working streaming TTS
- Full voice pipeline: wake word → STT → process → TTS

---

## Phase 5 — MCP Integration

JARVIS gains access to thousands of community tools.

### M019: MCP Client `[ ]`

**What to build:**
- `MCPClient` — connects to an MCP server process via stdin/stdout JSON-RPC
- Handshake: initialize, exchange capabilities
- Discover tools: list tools from server, convert to ToolDefinitions
- Execute tools: send call, receive result
- Lifecycle: start server process, health check, restart on crash

**Test criteria:**
- Test handshake with mock MCP server
- Test tool discovery parses server tools correctly
- Test tool execution sends correct JSON-RPC and parses result
- Test server crash triggers restart
- Test timeout on unresponsive server

**Deliverables:**
- MCP client, fully tested

---

### M020: MCP Server Manager + Integration `[ ]`

**What to build:**
- `MCPServerManager` — manages multiple MCP server processes
- Configuration: servers defined in settings (name, command, arguments, env vars)
- Auto-start enabled servers on app launch
- Register MCP tools in ToolRegistry with prefix: `mcp__<serverName>__<toolName>`
- Settings UI: add/remove/enable/disable MCP servers
- Timeout: don't block the orchestrator waiting for slow servers (start in background, tools appear when ready)

**Test criteria:**
- Test server start/stop lifecycle
- Test tools register in ToolRegistry with correct prefix
- Test disabled servers don't start
- Test slow server doesn't block orchestrator
- Integration: fixture test where Claude uses an MCP tool

**Deliverables:**
- MCP fully integrated
- Users can add MCP servers in settings
- Claude sees MCP tools alongside built-in tools

---

## Phase 6 — Memory and Intelligence

JARVIS starts remembering and anticipating.

### M021: Conversation Persistence `[ ]`

**What to build:**
- `ConversationStore` — save and load conversation history
- Encryption at rest using CryptoKit (AES-GCM, key derived from user's Keychain)
- Auto-save after each message
- Load last conversation on app launch (option to continue or start fresh)
- Conversation list: multiple saved conversations, deletable

**Test criteria:**
- Test save and load roundtrip (data integrity)
- Test encryption: saved file is not readable as plain text
- Test decryption with correct key succeeds
- Test decryption with wrong key fails gracefully
- Test conversation list CRUD

**Deliverables:**
- Encrypted conversation persistence
- Conversation history management

---

### M022: Episodic Memory `[ ]`

**What to build:**
- `MemoryStore` — SQLite database for memories
- At conversation end: send conversation to Claude with "summarise this and extract key user facts"
- Store: session summary, extracted facts, timestamp
- At conversation start: retrieve recent and relevant memories, inject into system prompt
- Relevance: keyword matching on facts (full vector search comes later in M029)
- Settings: view memories, delete individual memories, clear all

**Test criteria:**
- Test memory creation from conversation summary
- Test fact extraction parsing
- Test relevant memory retrieval (keyword match)
- Test memory injection into system prompt
- Test memory deletion
- Integration: two-conversation test where second conversation references facts from first

**Deliverables:**
- JARVIS remembers things between conversations
- Users can manage their memory

---

### M023: Context Compression `[ ]`

**What to build:**
- When conversation history exceeds token limit (configurable, default 50,000 tokens):
  - Summarise older messages into a compact "so far" block
  - Keep recent messages (last 10) in full
  - Replace old messages with the summary
- Token counting: rough estimate based on character count (4 chars ≈ 1 token)
- This saves money on long conversations and prevents context window overflow

**Test criteria:**
- Test compression triggers at correct threshold
- Test summary preserves key information (test with known conversation)
- Test recent messages preserved in full
- Test compressed context still allows Claude to answer follow-up questions

**Deliverables:**
- Long conversations work without hitting context limits or getting expensive

---

### M024: Task Manager (Long-Running Workflows) `[ ]`

**What to build:**
- `TaskManager` — handles multi-step tasks that take minutes or hours
- Task decomposition: Claude breaks task into numbered steps
- Checkpointing: save progress after each step (step number, results so far, state)
- Resume: on app launch, check for incomplete tasks, offer to resume
- Progress UI: show current step and total ("Step 3/7: Comparing flight prices...")
- Per-step timeout (not per-task)
- Dynamic round limits per step based on step complexity

**Test criteria:**
- Test task decomposition (Claude breaks "plan a trip" into steps)
- Test checkpoint save and load
- Test resume from checkpoint
- Test progress reporting
- Test step timeout enforcement
- Integration: full multi-step task with MockModelProvider

**Deliverables:**
- JARVIS can handle complex, long-running workflows
- Tasks survive app restarts

---

## Phase 7 — Personality and Polish

JARVIS becomes enjoyable to use.

### M025: Personality System `[ ]`

**What to build:**
- Personality presets: Professional, Friendly, Sarcastic, British Butler
- Custom personality: free-text description in settings
- Personality affects the system prompt sent to Claude
- Preview: test personality with a sample response in settings
- Personality affects both text and voice responses

**Test criteria:**
- Test each preset generates correct system prompt text
- Test custom personality injects user text into system prompt
- Test personality change takes effect on next message (not mid-conversation)
- Test preset preview shows sample response

**Deliverables:**
- Users can pick or create a personality for JARVIS

---

### M026: Settings and Onboarding `[ ]`

**What to build:**
- Complete settings view (split into tab files, each under 300 lines):
  - General: personality, autonomy level, startup behavior
  - API Keys: Anthropic key (stored in Keychain), Deepgram key
  - Voice: enable/disable, wake phrase, voice selection, TTS speed
  - MCP: server management
  - Memory: view/delete memories
  - Advanced: round limits, timeouts, logging level
- First-launch onboarding:
  - Welcome screen explaining what JARVIS is
  - API key entry
  - Accessibility permission grant
  - Microphone permission grant
  - Optional: Screen Recording permission
  - Personality selection
  - "Say hi to JARVIS" test

**Test criteria:**
- Test settings save and persist between launches
- Test API key stored in Keychain (not UserDefaults)
- Test onboarding flow completes in correct order
- Test missing permissions show clear guidance

**Deliverables:**
- Complete, polished settings
- Smooth first-launch experience

---

### M027: Ambient Awareness `[ ]`

**What to build:**
- `AmbientMonitor` with pluggable observers:
  - `ClipboardObserver` — polls pasteboard every 2 seconds, detects URLs, email addresses, code snippets, errors
  - `CalendarObserver` — checks EventKit for upcoming events, suggests actions 5 minutes before
  - `IdleObserver` — detects user inactivity via CGEventSource, offers help after configurable delay
- Suggestions appear as subtle inline messages in chat (not popups)
- Rate limiting: max 1 suggestion per 5 minutes
- Settings: enable/disable each observer, adjust timing

**Test criteria:**
- ClipboardObserver: test URL detection, email detection, code detection
- CalendarObserver: test upcoming event detection
- IdleObserver: test fires after configured delay
- Rate limiting: test second suggestion within 5 minutes is suppressed
- Test disable/enable per observer

**Deliverables:**
- JARVIS feels alive — noticing things and offering help proactively

---

## Phase 8 — Self-Improvement and Advanced Features

JARVIS gets smarter and more capable.

### M028: Self-Built Tools `[ ]`

**What to build:**
- When JARVIS can't do something, it can write a script and save it as a new custom tool
- Custom tool storage: `~/Library/Application Support/com.aidaemon/custom-tools/`
- Each custom tool: a shell script or Python script + a JSON definition file
- Claude writes the script, tests it, and registers it
- Custom tools appear in settings where users can view, edit, or delete them
- Risk level for custom tools: always "caution" or higher (never auto-safe)

**Test criteria:**
- Test custom tool creation (script + definition)
- Test custom tool registration in ToolRegistry
- Test custom tool execution
- Test custom tool appears in settings
- Test custom tool deletion removes from registry
- Test risk level enforcement

**Deliverables:**
- JARVIS can extend its own capabilities
- Users can manage custom tools

---

### M029: Vector Memory (sqlite-vec) `[ ]`

**What to build:**
- Add sqlite-vec extension to the SQLite database
- Generate embeddings for all stored memories (using OpenAI text-embedding-3-small or Apple NLEmbedding)
- Semantic search: find memories by meaning, not just keywords
- Hybrid retrieval: combine vector similarity + FTS5 keyword match
- Re-rank results for relevance
- Background indexing: new memories get embedded asynchronously

**Test criteria:**
- Test embedding generation for text
- Test vector search returns semantically similar results
- Test hybrid search combines vector + keyword results
- Test background indexing completes without blocking UI
- Test retrieval with known memories produces expected matches

**Deliverables:**
- Memory system upgraded to semantic search
- "What restaurant did I like?" finds the ramen memory even without the word "restaurant"

---

### M030: Phone Notifications for Approvals `[ ]`

**What to build:**
- Companion notification system (implementation TBD — could be iOS app, iMessage, email, or push notification)
- When JARVIS needs approval for a dangerous action and the user isn't at the Mac:
  - Send notification with action description
  - User approves/denies remotely
  - JARVIS continues or aborts
- Timeout: if no response within configurable period (default 1 hour), abort the step

**Test criteria:**
- Test notification sent when approval needed and user inactive
- Test approval resumes execution
- Test denial aborts step
- Test timeout aborts step

**Deliverables:**
- Users can approve dangerous actions from their phone
- Long-running background tasks don't stall waiting for the user to return

---

## Phase 9 — Ship It

### M031: Security Audit `[ ]`

**What to build:**
- Review all tool executors for injection vulnerabilities
- Review all file operations for path traversal
- Review all network calls for proper TLS
- Review Keychain usage for proper access control
- Review conversation encryption implementation
- Verify kill switch works from every state
- Verify destructive actions always confirm
- Penetration test: try prompt injection attacks against the system prompt
- Document findings and fixes

**Test criteria:**
- All identified vulnerabilities fixed
- Prompt injection test suite passes (adversarial inputs don't bypass safety)
- Kill switch works from every reachable state

**Deliverables:**
- Security audit report
- All findings resolved

---

### M032: Auto-Updates and Distribution `[ ]`

**What to build:**
- Sparkle integration for auto-updates
- Code signing with Developer ID
- Notarisation via Apple
- DMG packaging for distribution
- Update server (could use GitHub Releases or AWS S3)
- Update check on launch + periodic (every 24 hours)

**Test criteria:**
- Test update check finds new version
- Test update downloads and installs
- Test app is properly signed and notarised
- Test DMG mounts and app copies to /Applications

**Deliverables:**
- Distributable, auto-updating macOS app

---

### M033: Beta Release `[ ]`

**What to build:**
- Landing page (simple, can be GitHub Pages or similar)
- Beta signup form
- TestFlight or direct DMG distribution
- Crash reporting (could use Apple's built-in crash reporter)
- Usage analytics (opt-in, privacy-respecting — basic: sessions, tool usage, error rates)
- Feedback mechanism (in-app, sends to email or GitHub issue)

**Test criteria:**
- Full end-to-end test of the user journey: download → install → onboard → first conversation → voice → computer control
- Test crash reporter captures and sends reports
- Test feedback mechanism works

**Deliverables:**
- JARVIS is in real users' hands
- Feedback loop established

---

## Future Phases (Post-Launch)

These are planned but not detailed yet. They'll be fleshed out based on beta feedback.

- **Capability suggestions** — When JARVIS can't do something, suggest MCP plugins or offer to build a custom tool
- **Multi-workflow** — Run multiple tasks in parallel
- **Expose as MCP server** — Let other AI tools use JARVIS's computer control
- **Apple Foundation Models integration** — Use Apple's on-device AI for simple tasks (free, offline)
- **Plugin marketplace** — Curated MCP servers with one-click install
- **Team features** — Shared workflows, shared memory, admin controls
