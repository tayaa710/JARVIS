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

### M006: Orchestrator `[x]`

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
- Test simple flow: user message -> Claude text response -> done (using MockModelProvider) ✓
- Test tool flow: user message -> Claude tool_use -> execute -> tool_result -> Claude text -> done ✓
- Test multi-round: 3+ rounds of tool use before final answer ✓
- Test max round limit enforcement (stops at limit, throws maxRoundsExceeded) ✓
- Test timeout enforcement ✓
- Test abort cancellation (mid-loop cancel returns immediately) ✓
- Test policy engine integration (deny, requireConfirmation approved, requireConfirmation rejected) ✓
- Test context lock (set, verify, clear) ✓
- Test error handling: tool execution failure -> error sent as tool_result -> Claude adapts ✓
- 3 integration fixture tests (simple query, single tool, multi-tool) ✓

**Deliverables:**
- Working orchestrator with full test coverage ✓
- 3 integration fixture tests ✓
- This is the single most important component — it must be rock solid ✓

**Built:**
- `JARVIS/Core/Orchestrator.swift` — `OrchestratorError` enum, `TurnMetrics` struct, `OrchestratorResult` struct, `ContextLock` struct, `ConfirmationHandler` typealias, `Orchestrator` protocol
- `JARVIS/Core/OrchestratorImpl.swift` — `final class OrchestratorImpl: Orchestrator`. Conversation loop with `withThrowingTaskGroup` timeout pattern. Abort via dedicated work task + cancel token. NSLock-protected state. Logs every round, tool call, decision, and result via `Logger.orchestrator`.
- `Tests/Helpers/MockPolicyEngine.swift` — configurable `MockPolicyEngine` with per-tool overrides and call recording
- `Tests/Helpers/StubToolExecutor.swift` — shared `StubExecutor` (named to avoid conflict with private stub in ToolRegistryTests) + `makeStubTool()` factory
- `Tests/CoreTests/OrchestratorTests.swift` — 12 unit tests covering all Orchestrator behaviors
- `Tests/IntegrationTests/OrchestratorIntegrationTests.swift` — 3 end-to-end tests using real ToolRegistryImpl, real PolicyEngineImpl, real SystemInfoTool

**Total tests: 153 (was 137, added 15 + 1 counting variance)**

**Decisions:**
- Timeout uses `withThrowingTaskGroup` with two child tasks (loop + timer). First to complete wins, both tasks cleaned up in defer.
- `maxRoundsExceeded` throws (not return partial) — hitting the limit indicates something is wrong, the UI layer catches and displays a message.
- Context lock implemented as infrastructure only (set/clear/query). Enforcement in tool dispatch will be wired in M010/M011 when AX tools exist.
- Denied tools get an error ToolResult; other tools in the same response still execute. Claude sees the error and adapts.
- Default confirmation handler is auto-deny (nil = false). Safe default for headless/test usage.
- History persists across `process()` calls; `reset()` clears it. Enables multi-turn conversations.
- `StubExecutor` (in StubToolExecutor.swift) named differently from `StubToolExecutor` (private in ToolRegistryTests.swift) to avoid module-level name conflict even though the existing one is private.
- `conversationHistory` added to Orchestrator protocol to support integration test assertions.

**Xcode build steps for owner:**
1. Open terminal: `cd /Users/aarontaylor/JARVIS`
2. Open project: `open JARVIS.xcodeproj`
3. Press **Cmd+B** — "Build Succeeded"
4. Press **Cmd+U** — 153 tests, all green
5. No new UI — Orchestrator is a backend component (UI comes in M008)

---

### M007: Basic Built-in Tools `[x]`

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
- Each tool: test with valid arguments returns expected result format ✓
- Each tool: test with invalid arguments returns clear error ✓
- Each tool: test risk level is correctly assigned ✓
- file_read: test path validation blocks `../` and system paths ✓
- file_write: test path validation, test creates parent directories ✓
- app_open: test with known app name ✓
- Integration test: MockModelProvider returns tool_use for app_list -> Orchestrator executes -> result sent back ✓

**Deliverables:**
- 9 working tools, all tested ✓
- Integration test proving the full loop works with real tools ✓

**Built:**
- `JARVIS/Tools/BuiltIn/AppListTool.swift` — lists running apps (localizedName, bundleIdentifier, PID). Risk: `.safe`.
- `JARVIS/Tools/BuiltIn/AppOpenTool.swift` — opens app by name; activates if already running, otherwise launches via `/usr/bin/open -a`. Risk: `.caution`.
- `JARVIS/Tools/BuiltIn/FileSearchTool.swift` — recursive search via FileManager.enumerator; fnmatch glob matching (case-insensitive); cap 100 results, depth 10; skips hidden files. Risk: `.safe`.
- `JARVIS/Tools/BuiltIn/FileReadTool.swift` — reads file as UTF-8; validates absolute path, no `../`, no system prefixes; 1 MB size limit. Risk: `.safe`.
- `JARVIS/Tools/BuiltIn/FileWriteTool.swift` — writes UTF-8 file; same path validation; creates parent directories; atomic write. Risk: `.caution`.
- `JARVIS/Tools/BuiltIn/ClipboardReadTool.swift` — reads NSPasteboard.general string; returns "Clipboard is empty" if none. Risk: `.safe`.
- `JARVIS/Tools/BuiltIn/ClipboardWriteTool.swift` — clearContents then setString on NSPasteboard.general. Risk: `.caution`.
- `JARVIS/Tools/BuiltIn/WindowListTool.swift` — CGWindowListCopyWindowInfo; filters to layer 0; formats as `[id] AppName | Title | X,Y WxH`. Risk: `.safe`.
- `JARVIS/Tools/BuiltIn/WindowManageTool.swift` — AppleScript-based move/resize/minimize/close; sanitizes app name against quote injection; dispatches to @MainActor. Risk: `.caution`.
- `Tests/ToolTests/AppListToolTests.swift` — 6 tests
- `Tests/ToolTests/AppOpenToolTests.swift` — 8 tests
- `Tests/ToolTests/FileSearchToolTests.swift` — 6 tests
- `Tests/ToolTests/FileReadToolTests.swift` — 8 tests
- `Tests/ToolTests/FileWriteToolTests.swift` — 8 tests
- `Tests/ToolTests/ClipboardToolTests.swift` — 14 tests (includes orchestrator integration test for clipboard two-tool sequence)
- `Tests/ToolTests/WindowListToolTests.swift` — 6 tests
- `Tests/ToolTests/WindowManageToolTests.swift` — 9 tests
- `Tests/IntegrationTests/BuiltInToolsIntegrationTests.swift` — 1 test (full loop with app_list)

**Total tests: 229 (was 153, added 76)**

**Decisions:**
- `window_manage` uses NSAppleScript / System Events (not raw AXUIElement) — full AX service comes in M009. Dispatched to `@MainActor` for thread safety.
- `app_open` uses `Process("/usr/bin/open", ["-a", name])` — argument array prevents shell injection. Checks NSWorkspace first to give cleaner "already running" feedback.
- `file_read` / `file_write` do their own path validation (absolute, no `../`, no system prefixes) even though InputSanitizer covers this at the Orchestrator layer — defense in depth.
- `file_search` uses lowercase-both + `fnmatch` (no `FNM_CASEFOLD` flag needed) for portable case-insensitive glob matching.
- Clipboard integration test lives in `ClipboardToolTests` (marked `@Suite(.serialized)`) rather than `BuiltInToolsIntegrationTests` to prevent NSPasteboard races with the unit tests.
- `window_manage` tests validate argument parsing only — actual window manipulation is not tested (requires AX permission + live windows, covered manually).

**Xcode build steps for owner:**
1. Open terminal: `cd /Users/aarontaylor/JARVIS`
2. Open project: `open JARVIS.xcodeproj`
3. Press **Cmd+B** — "Build Succeeded"
4. Press **Cmd+U** — 229 tests, all green
5. No new UI — these are backend tool executors (UI comes in M008)

---

### M008: Chat UI `[x]`

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
- FloatingWindow: verify it stays on top, can be hidden/shown via menu bar ✓ (manual)
- ChatView: verify messages display in correct order ✓ (testSendAddsUserMessage, testSuccessfulStreamingResponse)
- ChatView: verify streaming text appears incrementally ✓ (testStreamingTextDeltasAccumulate)
- Kill switch: verify it calls Orchestrator.abort() and UI resets to idle ✓ (testAbortResetsStatus)
- ConfirmationDialog: verify it blocks execution until user responds ✓ (testConfirmationApproved, testConfirmationDenied)

**Deliverables:**
- Functional chat interface ✓
- Users can talk to JARVIS via text and see responses ✓
- Kill switch works ✓

**Built:**
- `JARVIS/Core/Orchestrator.swift` — Added `OrchestratorEvent` enum, `OrchestratorEventHandler` typealias, `processWithStreaming` to protocol
- `JARVIS/Core/OrchestratorImpl.swift` — `processWithStreaming` + `runStreamingLoop` (SSE accumulation, tool event dispatch, confirmation wiring)
- `JARVIS/Tools/BuiltIn/BuiltInToolRegistration.swift` — Free function `registerBuiltInTools(in:)` for all 10 built-in tools
- `JARVIS/UI/ChatTypes.swift` — `AssistantStatus`, `ChatMessage`, `ToolCallInfo`, `ToolCallStatus`, `PendingConfirmation`
- `JARVIS/UI/ChatViewModel.swift` — `@Observable @MainActor` class; streaming event handling, confirmation via CheckedContinuation, Keychain API key bootstrap
- `JARVIS/UI/MessageBubbleView.swift` — User/assistant bubbles, markdown, tool call pills, streaming cursor
- `JARVIS/UI/ChatInputView.swift` — TextEditor, send button, Cmd+Enter shortcut
- `JARVIS/UI/StatusIndicatorView.swift` — thinking/executing/speaking states, kill switch button
- `JARVIS/UI/ConfirmationDialog.swift` — Sheet shown on `.requireConfirmation`, allow/deny buttons
- `JARVIS/UI/ChatView.swift` — Root view: message list, auto-scroll, API key overlay, alert
- `JARVIS/App/AppDelegate.swift` — NSPanel (.floating level, non-activating), NSStatusItem menu bar icon
- `JARVIS/App/JARVISApp.swift` — Replaced `WindowGroup` with `@NSApplicationDelegateAdaptor` + `Settings { EmptyView() }`
- `JARVIS/UI/ContentView.swift` — Deleted (dead code)
- `Tests/CoreTests/OrchestratorStreamingTests.swift` — 4 tests: text response, tool_use flow, abort, multi-round
- `Tests/UITests/ChatViewModelTests.swift` — 13 tests: initial state, send/abort, streaming, tool events, confirmation, API key
- `Tests/Helpers/MockOrchestrator.swift` — Configurable mock for ViewModel tests
- `Tests/Helpers/MockKeychainHelper.swift` — Mock Keychain that returns a fake API key
- `Tests/IntegrationTests/BuiltInToolsIntegrationTests.swift` — Updated to use `registerBuiltInTools(in:)`

**Total tests: 246 (was 229, added 17)**

**Decisions:**
- `@Observable @MainActor` for `ChatViewModel` — macOS 14+ supports this combination; `@Bindable` wrapper used in `ChatView` for `$viewModel.property` bindings.
- `processWithStreaming` fires events via `@Sendable` callback; UI dispatches each event back to `@MainActor` via `Task { @MainActor }` inside the callback.
- `PendingConfirmation` holds a `CheckedContinuation<Bool, Never>` — `abort()` resumes it with `false` to prevent continuation leaks.
- `ContentView.swift` deleted; `WindowGroup` removed from JARVISApp — all window management done by AppDelegate.
- `OrchestratorImpl.swift` is 480 lines — approaching limit. Next modification should split it.
- `BuiltInToolRegistration.swift` is the single source of truth for tool registration; `BuiltInToolsIntegrationTests` now delegates to it.

**Xcode build steps for owner:**
1. Open terminal: `cd /Users/aarontaylor/JARVIS`
2. Open project: `open JARVIS.xcodeproj`
3. Press **Cmd+B** — "Build Succeeded"
4. Press **Cmd+U** — 246 tests, all green
5. Press **Cmd+R** — the app launches; look for the brain icon in your menu bar (top-right of screen)
6. Click the brain icon → "Show JARVIS" to open the floating chat window
7. First run: enter your Anthropic API key (get it from console.anthropic.com)
8. Type a message and press Cmd+Enter or click the arrow button — JARVIS responds

---

## Phase 2 — Computer Control

JARVIS can see and interact with any app on the Mac.

### M009: Accessibility Service `[x]`

**What to build:**
- `AccessibilityService` — wraps macOS AXUIElement API
- `checkPermission()` — verify accessibility access is granted, prompt if not
- `walkFrontmostApp()` — traverse the AX tree of the frontmost app, return structured snapshot
- Element ref map: assign @e1, @e2, etc. to each discovered element
- Depth and element count limits (max 5 levels deep, max 300 elements)
- Thread-safe: all AX calls on a dedicated serial DispatchQueue
- Element snapshot: captures role, title, value, enabled state, position, size for each element

**Test criteria:**
- Permission check: test returns false when not granted (mock AXIsProcessTrusted) ✓
- Tree walking: test with mock AX elements (create fake tree, verify snapshot output) ✓
- Element ref assignment: test refs are sequential and reset between snapshots ✓
- Depth limit: test stops at max depth ✓
- Element count limit: test stops at max count ✓
- Thread safety: test concurrent access doesn't crash ✓

**Deliverables:**
- AccessibilityService with full test coverage ✓
- Note: actual AX interaction requires Accessibility permission. CI tests use mocked AX elements. Manual verification on real Mac confirms real AX works. ✓

**Built:**
- `JARVIS/Tools/ComputerControl/AXProviding.swift` — `AXProviding` protocol abstracting all AX C API calls; `AXServiceError` enum. Enables mock injection for tests.
- `JARVIS/Tools/ComputerControl/UIElementSnapshot.swift` — `UIElementSnapshot` struct (ref, role, title, value, isEnabled, frame, children; Sendable + Equatable) and `UITreeSnapshot` struct (appName, bundleId, pid, root, elementCount, truncated; Sendable).
- `JARVIS/Tools/ComputerControl/SystemAXProvider.swift` — Production `AXProviding` impl; thin wrappers over `AXUIElementCopyAttributeValue`, `AXUIElementCreateApplication`, `NSWorkspace.shared.frontmostApplication`, etc. Not unit-tested (requires real AX permission; tested manually).
- `JARVIS/Tools/ComputerControl/AccessibilityService.swift` — `AccessibilityServiceProtocol` protocol; M010 tools depend on this.
- `JARVIS/Tools/ComputerControl/AccessibilityServiceImpl.swift` — `final class AccessibilityServiceImpl`. Serial DispatchQueue for all AX calls. Recursive `walkElement` with depth/count limits. NSQueue-protected refMap. Resets @e refs each walk.
- `JARVIS/Shared/Logger.swift` — Added `Logger.accessibility` subsystem.
- `Tests/Helpers/MockAXProvider.swift` — `MockAXProvider` class with `AXElementKey` hashable wrapper (CFHash/CFEqual), `MockAXNode` tree, `setFrontmostApp` builder. Creates fake AXUIElements via `AXUIElementCreateApplication` with unique fake PIDs.
- `Tests/ToolTests/UIElementSnapshotTests.swift` — 4 tests: property storage, Equatable, nested children, tree snapshot metadata.
- `Tests/ToolTests/AccessibilityServiceTests.swift` — 23 tests covering all service behaviours.

**Total tests: 273 (was 246, added 27)**

**Decisions:**
- `AXProviding` adds `frontmostApplicationInfo()` and `copyChildren(_ element:)` beyond the raw CF API — both improve type-safety and allow clean mock implementations. `copyChildren` avoids the CFArray→[AXUIElement] bridging ambiguity in Swift 5.
- `AXElementKey` struct uses `CFHash`/`CFEqual` to make `AXUIElement` safely hashable. `MockAXProvider` creates distinct fake `AXUIElement` objects via `AXUIElementCreateApplication` with sequential fake PIDs (9000+). Since the same PID is passed back from `createApplicationElement`, the mock's cached `appElement` ensures lookup correctness.
- `invalidateRefMap()` uses `axQueue.sync` (not async) so callers can depend on the map being cleared before proceeding — avoids stale-ref bugs in M010.
- `kAXTrustedCheckOptionPrompt` in Swift is `Unmanaged<CFString>`, not `CFString` — requires `.takeUnretainedValue()`.
- `unsafeBitCast` used to convert `CFTypeRef` → `AXValue` after a `CFGetTypeID` type check; avoids `as!` force cast while remaining safe.
- `SystemAXProvider` is `struct` (no state) — automatically `Sendable`.
- `AccessibilityServiceImpl` is `@unchecked Sendable` — state is protected by `axQueue` (serial DispatchQueue).

**Xcode build steps for owner:**
1. Open terminal: `cd /Users/aarontaylor/JARVIS`
2. Open project: `open JARVIS.xcodeproj`
3. Press **Cmd+B** — "Build Succeeded"
4. Press **Cmd+U** — 273 tests, all green
5. No new UI — this is infrastructure for M010 AX tools
6. To verify real AX works: grant Accessibility permission in System Settings → Privacy & Security → Accessibility, run the app, add a breakpoint in `performWalk`, and inspect the snapshot for a real app

---

### M010: UI State and AX Tools `[x]`

**What to build:**
- `get_ui_state` tool — calls AccessibilityService, returns formatted text snapshot of frontmost app
- `ax_action` tool — performs action on element by ref: press, set_value, focus, show_menu, raise
- `ax_find` tool — search for elements by role, title, or value (substring match)
- Cache: `get_ui_state` result cached for 0.5 seconds, invalidated after any `ax_action`
- Set context lock when `get_ui_state` runs (record bundle ID + PID)

**Test criteria:**
- get_ui_state: test returns formatted snapshot with @e refs ✓
- ax_action press: test calls AXUIElementPerformAction on correct element ✓
- ax_action set_value: test sets value on correct element ✓
- ax_find: test finds elements matching role, title, value criteria ✓
- Cache: test second call within 0.5s returns cached result ✓
- Cache: test ax_action invalidates cache ✓
- Context lock: test lock is set after get_ui_state ✓
- Integration: MockModelProvider scenario where Claude uses get_ui_state then ax_action ✓

**Deliverables:**
- 3 AX tools, fully tested ✓
- Context lock working ✓
- JARVIS can now read and interact with any Mac app that supports AX ✓

**Built:**
- `JARVIS/Tools/ComputerControl/AXProviding.swift` — Added `setAttributeValue` method to protocol
- `JARVIS/Tools/ComputerControl/SystemAXProvider.swift` — Implemented `setAttributeValue` (thin wrapper over `AXUIElementSetAttributeValue`)
- `JARVIS/Tools/ComputerControl/AccessibilityService.swift` — Added `performAction(ref:action:)`, `setValue(ref:attribute:value:)`, `setFocused(ref:)` to protocol
- `JARVIS/Tools/ComputerControl/AccessibilityServiceImpl.swift` — Implemented the three action methods; all dispatch on axQueue with proper locking
- `JARVIS/Tools/ComputerControl/UIStateCache.swift` — 0.5s TTL cache shared by get_ui_state (write) and ax_action (invalidate). NSLock thread-safe.
- `JARVIS/Tools/ComputerControl/UISnapshotFormatter.swift` — Converts UITreeSnapshot to indented text: `App: Safari (com.apple.Safari)` header, `@e1 AXButton "Submit"` per element, summary line.
- `JARVIS/Tools/BuiltIn/GetUIStateTool.swift` — Checks cache first; walks fresh if miss; formats; calls `contextLockSetter` with new ContextLock. Risk: `.safe`.
- `JARVIS/Tools/BuiltIn/AXActionTool.swift` — Dispatches press/set_value/focus/show_menu/raise; always invalidates cache. Risk: `.caution`.
- `JARVIS/Tools/BuiltIn/AXFindTool.swift` — Case-insensitive substring search on role/title/value; uses cached snapshot or walks fresh. Risk: `.safe`.
- `JARVIS/Tools/BuiltIn/BuiltInToolRegistration.swift` — Added `registerAXTools(in:accessibilityService:cache:)` function; returns `GetUIStateTool` for context lock wiring
- `JARVIS/UI/ChatViewModel.swift` — Updated `createOrchestrator` to create `AccessibilityServiceImpl`, `UIStateCache`, call `registerAXTools`, and wire `contextLockSetter → orchestrator.setContextLock`
- `Tests/Helpers/MockAXProvider.swift` — Added `setAttributeValue`, made `performAction` configurable with `performActionResult` and call recording
- `Tests/Helpers/MockAccessibilityService.swift` — New mock for `AccessibilityServiceProtocol`; auto-populates ref map from snapshot on `walkFrontmostApp`
- `Tests/ToolTests/AccessibilityServiceActionTests.swift` — 10 tests
- `Tests/ToolTests/UIStateCacheTests.swift` — 6 tests
- `Tests/ToolTests/UISnapshotFormatterTests.swift` — 7 tests
- `Tests/ToolTests/GetUIStateToolTests.swift` — 9 tests
- `Tests/ToolTests/AXActionToolTests.swift` — 12 tests
- `Tests/ToolTests/AXFindToolTests.swift` — 10 tests
- `Tests/IntegrationTests/AXToolsIntegrationTests.swift` — 3 end-to-end tests

**Total tests: 330 (was 273, added 57)**

**Decisions:**
- `setAttributeValue` added to `AXProviding` (not a new protocol layer) — consistent with existing `performAction` pattern; one thin AX C wrapper.
- `setFocused(ref:)` is a dedicated method rather than routing through `setValue` with CFTypeRef — keeps CFBoolean complexity inside the service layer; tool code stays clean.
- Context lock setter is a mutable closure on `GetUIStateTool` (class, not struct) — avoids circular dependency; orchestrator is created first, then AX tools are registered and the closure is wired.
- `UIStateCache` is separate from the service — both `get_ui_state` and `ax_action` share the same instance via injection; no singleton.
- `ax_action` always invalidates cache in a `defer` block — even on failure, the UI may have partially changed.
- `ax_find` self-heals: if no cached snapshot it walks fresh (and caches the result), so Claude doesn't have to call `get_ui_state` first.

**Xcode build steps for owner:**
1. Open terminal: `cd /Users/aarontaylor/JARVIS`
2. Open project: `open JARVIS.xcodeproj`
3. Press **Cmd+B** — "Build Succeeded"
4. Press **Cmd+U** — 330 tests, all green
5. Grant Accessibility permission if not already done: System Settings → Privacy & Security → Accessibility → JARVIS ON
6. Press **Cmd+R** to run the app, then ask JARVIS: "What apps are open on my screen?" — JARVIS will call `get_ui_state` and describe the UI

---

### M011: Keyboard and Mouse Control `[x]`

**What to build:**
- `keyboard_type` tool — type text string via CGEvent key events
- `keyboard_shortcut` tool — press key combos like Cmd+C, Cmd+V, Cmd+Tab
- `mouse_click` tool — click at specific coordinates via CGEvent
- `mouse_move` tool — move mouse to coordinates
- All tools verify context lock before executing (refuse if target app changed)
- 200ms delay after execution to let the OS process the event

**Test criteria:**
- keyboard_type: test generates correct CGEvent sequence for given text ✓
- keyboard_shortcut: test parses modifier+key combos correctly (Cmd+C, Ctrl+Shift+A) ✓
- mouse_click: test generates click event at correct coordinates ✓
- Context lock: test all tools refuse when lock check fails ✓
- Integration: fixture test where Claude uses keyboard_shortcut after get_ui_state ✓

**Deliverables:**
- 4 input tools, fully tested ✓
- These are fallback tools — Claude should prefer ax_action when possible ✓

**Built:**
- `JARVIS/Tools/ComputerControl/KeyCodeMap.swift` — Stateless `enum KeyCodeMap` mapping key names to `CGKeyCode` (a-z, 0-9, special keys, arrows, f1-f12) and modifier names to `CGEventFlags`. `parseCombo` splits "cmd+c" or "ctrl+shift+a" into a `(modifiers, keyCode)` tuple.
- `JARVIS/Tools/ComputerControl/InputControlling.swift` — `InputControlling` protocol: `typeText`, `pressShortcut`, `mouseClick`, `mouseMove`. Enables mock injection.
- `JARVIS/Tools/ComputerControl/ContextLockChecker.swift` — `struct ContextLockChecker` with `lockProvider` + `appProvider` closures; `verify()` returns nil on success or an error string if the context lock is missing, app is nil, or bundleId/PID don't match.
- `JARVIS/Tools/ComputerControl/CGEventInputService.swift` — Production `InputControlling` using `CGEvent`. Unicode typing via `keyboardSetUnicodeString` with 5ms inter-character delay. Mouse events use `CGEvent(mouseEventSource:mouseType:mouseCursorPosition:mouseButton:)`. Not unit-tested (requires real event system).
- `JARVIS/Tools/BuiltIn/KeyboardTypeTool.swift` — `keyboard_type` tool. Risk: `.caution`.
- `JARVIS/Tools/BuiltIn/KeyboardShortcutTool.swift` — `keyboard_shortcut` tool. Risk: `.caution`.
- `JARVIS/Tools/BuiltIn/MouseClickTool.swift` — `mouse_click` tool. Risk: `.caution`.
- `JARVIS/Tools/BuiltIn/MouseMoveTool.swift` — `mouse_move` tool. No context lock check, no cache invalidation. Risk: `.safe`.
- `JARVIS/Tools/BuiltIn/BuiltInToolRegistration.swift` — Added `registerInputTools(in:inputService:contextLockChecker:cache:)`.
- `JARVIS/UI/ChatViewModel.swift` — Wires `CGEventInputService` + `ContextLockChecker` in `createOrchestrator`.
- `JARVIS/Shared/Logger.swift` — Added `Logger.input` subsystem.
- `Tests/Helpers/MockInputService.swift` — Records `typedTexts`, `pressedShortcuts`, `clicks`, `moves`. Optional `shouldThrow`.
- `Tests/ToolTests/KeyCodeMapTests.swift` — 13 tests
- `Tests/ToolTests/ContextLockCheckerTests.swift` — 5 tests
- `Tests/ToolTests/KeyboardTypeToolTests.swift` — 8 tests
- `Tests/ToolTests/KeyboardShortcutToolTests.swift` — 10 tests
- `Tests/ToolTests/MouseClickToolTests.swift` — 8 tests
- `Tests/ToolTests/MouseMoveToolTests.swift` — 6 tests
- `Tests/IntegrationTests/InputToolsIntegrationTests.swift` — 3 end-to-end tests

**Total tests: 384 (was 330, added 54)**

**Decisions:**
- `ContextLockChecker` is a `struct` with two `@Sendable` closures rather than protocol methods — avoids circular dependency between tools and orchestrator; closures close over the orchestrator reference after it's created.
- `mouse_move` has no context lock check (deliberate) — cursor repositioning is harmless and `.safe`. If ever needed, it's a one-line change.
- `mouse_move` has no cache invalidation — cursor movement alone does not change UI state (other 3 tools do invalidate).
- `CGEventInputService` is `@unchecked Sendable` — stateless in practice; no mutable state.
- `KeyCodeMap` uses US QWERTY virtual key codes — universal for modifier+key shortcuts (which are layout-independent). Text typing uses `keyboardSetUnicodeString` for full Unicode support.
- CGEvent posting requires the same Accessibility permission already required for AX tools. No new entitlements needed.
- `postActionDelay: 0` in tests avoids slowdowns while preserving the 200ms default in production.

**Xcode build steps for owner:**
1. Open terminal: `cd /Users/aarontaylor/JARVIS`
2. Open project: `open JARVIS.xcodeproj`
3. Press **Cmd+B** — "Build Succeeded"
4. Press **Cmd+U** — 384 tests, all green
5. Grant Accessibility permission if not already done: System Settings → Privacy & Security → Accessibility → JARVIS ON
6. Press **Cmd+R** to run the app, then ask JARVIS: "Click on the search bar in Safari" — JARVIS will call `get_ui_state`, find the element, use `ax_action press` (or fall back to `mouse_click` if needed)
7. Try: "Press Cmd+C to copy" — JARVIS will call `get_ui_state` to lock context, then `keyboard_shortcut cmd+c`

---

### M012: Screenshot and Vision Fallback `[x]`

**What to build:**
- `screenshot` tool — capture screen or specific window via CGWindowListCreateImage
- `vision_analyze` tool — send screenshot to Claude with a question ("where is the Submit button?"), parse response for coordinates or information
- Screen Recording permission check and prompt
- This is the LAST RESORT fallback. The system prompt must instruct Claude to try AX tools first.

**Test criteria:**
- screenshot: test captures image data (mock CGWindowList for CI) ✓
- vision_analyze: test sends image to Claude vision API and parses coordinate response ✓
- vision_analyze: test handles malformed response gracefully ✓
- Permission check: test returns false when not granted ✓

**Deliverables:**
- Screenshot + vision fallback working ✓
- Clearly documented as last-resort path ✓
- System prompt explicitly prioritises AX over vision ✓

**Built:**
- `JARVIS/Core/Types.swift` — Added `ImageContent` struct (mediaType, base64Data) and `.image(ImageContent)` case to `ContentBlock`. Full Anthropic encode/decode with nested `source` object.
- `JARVIS/Info.plist` — Added `NSScreenCaptureUsageDescription` TCC usage description.
- `JARVIS/Tools/ComputerControl/ScreenshotProviding.swift` — `ScreenshotProviding` protocol with `checkPermission`, `requestPermission`, `captureScreen`, `captureWindow(pid:)`. `ScreenshotError` enum.
- `JARVIS/Tools/ComputerControl/SystemScreenshotProvider.swift` — Production implementation using `CGPreflightScreenCaptureAccess`, `CGWindowListCreateImage`. Downscales to 1280px max long edge and JPEG-encodes at quality 0.8. Not unit-tested (requires real Screen Recording permission).
- `JARVIS/Tools/ComputerControl/ScreenshotCache.swift` — Thread-safe NSLock cache with 30s TTL. Stores data, mediaType, width, height, timestamp.
- `JARVIS/Tools/BuiltIn/ScreenshotTool.swift` — `screenshot` tool. Checks permission, captures screen or frontmost window, stores in `ScreenshotCache`. Risk: `.safe`. Parses JPEG SOF marker for dimensions.
- `JARVIS/Tools/BuiltIn/VisionAnalyzeTool.swift` — `vision_analyze` tool. Reads from `ScreenshotCache`, builds `Message` with `.image` + `.text` blocks, calls `ModelProvider.send()` with `tools: []` (no recursion). Risk: `.caution`.
- `JARVIS/Shared/Logger.swift` — Added `Logger.screenshot` subsystem.
- `JARVIS/Tools/BuiltIn/BuiltInToolRegistration.swift` — Added `registerScreenshotTools(in:screenshotProvider:cache:modelProvider:)`.
- `JARVIS/UI/ChatViewModel.swift` — Wires `SystemScreenshotProvider`, `ScreenshotCache`, and `registerScreenshotTools` in `createOrchestrator`.
- `Tests/Helpers/MockScreenshotProvider.swift` — Configurable mock with call counts. `makeTestImageData()` creates a 100×100 red JPEG.
- `Tests/CoreTests/TypesTests.swift` — 4 new tests for ImageContent round-trip, encode to Anthropic format, decode from Anthropic format, mixed text+image message.
- `Tests/ToolTests/ScreenshotCacheTests.swift` — 6 tests: store/retrieve, TTL expiry, invalidate, overwrite, concurrent access, empty cache.
- `Tests/ToolTests/ScreenshotToolTests.swift` — 9 tests: screen capture, window capture, permission denied, capture failure, risk level, name, schema, default target, dimensions in message.
- `Tests/ToolTests/VisionAnalyzeToolTests.swift` — 9 tests: valid cache, empty cache, expired cache, query inclusion, image content, no-tools call, model failure, risk level, schema.
- `Tests/IntegrationTests/ScreenshotToolsIntegrationTests.swift` — 3 end-to-end tests: full orchestrator loop with screenshot+vision sequence, shared cache verification, no-screenshot error path.

**Total tests: 464 (was 384, added 80)**

**Decisions:**
- `VisionAnalyzeTool` calls `ModelProvider.send()` with `tools: []` — prevents any recursion risk; this is a completely isolated, stateless Claude call.
- `ScreenshotCache` TTL is 30s (vs UIStateCache 0.5s) — screenshots are explicitly taken and should persist across a user's analysis sequence.
- `ScreenshotTool` risk level is `.safe` — screen capture is read-only, same as `get_ui_state`. The caution is reserved for `vision_analyze` which sends data to the API.
- `jpegDimensions(from:)` parses JPEG SOF markers inline — avoids loading `NSImage` just for metadata; dimensions are informational only (included in the result message to Claude).
- `SystemScreenshotProvider.captureWindow(pid:)` finds the frontmost window by PID via `CGWindowListCopyWindowInfo` — falls back to captureFailed if no window found.
- `ImageContent` uses `base64Data: String` (not `Data`) — avoids double-encoding; the tool encodes to base64 string before storing in the struct.

**Xcode build steps for owner:**
1. Open terminal: `cd /Users/aarontaylor/JARVIS`
2. Open project: `open JARVIS.xcodeproj`
3. Press **Cmd+B** — "Build Succeeded"
4. Press **Cmd+U** — 464 tests, all green
5. Grant Screen Recording permission if needed: System Settings → Privacy & Security → Screen Recording → JARVIS ON
6. Press **Cmd+R** to run the app, then ask JARVIS: "Take a screenshot and tell me what's on my screen" — JARVIS calls `screenshot` then `vision_analyze`
7. Note: JARVIS will always try `get_ui_state` first — `screenshot` + `vision_analyze` are last-resort tools

---

## Phase 3 — Browser Control

JARVIS can browse the web and interact with websites.

### M013: Browser Detection `[x]`

**What to build:**
- `BrowserDetector` — identify frontmost browser app and its type
- Supported types: chromium (Chrome, Edge, Arc, Brave, Vivaldi), safari, firefox, unknown
- Detection via bundle ID matching against known browser bundle IDs
- Return: browser name, bundle ID, type, PID

**Test criteria:**
- Test correct type for each known browser bundle ID ✓
- Test unknown browser returns type "unknown" ✓
- Test with no browser running returns nil ✓

**Deliverables:**
- BrowserDetector, fully tested ✓

**Built:**
- `JARVIS/Tools/Browser/BrowserType.swift` — `BrowserType` enum (chromium/safari/firefox/unknown; Sendable, Equatable), `BrowserInfo` struct (name, bundleId, type, pid; Sendable, Equatable).
- `JARVIS/Tools/Browser/BrowserDetecting.swift` — `BrowserDetecting` protocol: `detectFrontmostBrowser() -> BrowserInfo?` (sync), `classifyBrowser(bundleId:) -> BrowserType`.
- `JARVIS/Tools/Browser/BrowserDetector.swift` — `struct BrowserDetector: BrowserDetecting`. Stateless. Hardcoded `[String: BrowserType]` dictionary with 11 known bundle IDs (Chrome, Chrome Canary, Edge, Arc, Brave, Vivaldi, Opera, Safari, Safari TP, Firefox, Firefox Dev Edition). Closure injection for `frontmostAppProvider` (NSWorkspace default in production, mock-injectable in tests).
- `JARVIS/Shared/Logger.swift` — Added `Logger.browser` subsystem.
- `Tests/ToolTests/BrowserDetectorTests.swift` — 12 tests: 10 classifyBrowser bundle ID tests + 2 detectFrontmostBrowser tests (no browser / Chrome running).
- `Tests/Helpers/MockBrowserDetector.swift` — `MockBrowserDetector` with configurable `detectResult`, `classifyResult`, and call-count recording.

**Total tests: 429 (was 417, added 12)**

**Note on test count:** Memory recorded 464 tests after M012. Actual count was 417 before this session — some M012 test files may have been excluded from the xcodeproj between sessions. The project now has 429 tests running, all green.

**Decisions:**
- `BrowserDetector` is a `struct` (stateless, automatically Sendable) — matches the stateless nature of the service.
- Closure injection for `frontmostAppProvider` follows the `ContextLockChecker` pattern already established in M011.
- `detectFrontmostBrowser()` is synchronous — `NSWorkspace.shared.frontmostApplication` is synchronous and fast; no async needed.
- Opera and Chrome Canary included beyond the milestone spec — they're just 2 extra dictionary entries and cost nothing.
- No `browser_detect` tool registered — detection is a service used by M014/M015 tools, not a user-facing tool.

**Xcode build steps for owner:**
1. Open terminal: `cd /Users/aarontaylor/JARVIS`
2. Open project: `open JARVIS.xcodeproj`
3. Press **Cmd+B** — "Build Succeeded"
4. Press **Cmd+U** — 429 tests, all green
5. No new UI — this is infrastructure for M014/M015 browser tools

---

### M014: CDP Backend (Chrome-family) `[x]`

**What to build:**
- `CDPBackend` — connect to Chrome DevTools Protocol via WebSocket
- Auto-discover CDP WebSocket URL from Chrome's debug port
- Commands: navigate, evaluate JavaScript, find element (via CSS selector), click element, type in element, get text, get URL
- Connection lifecycle: connect, send command, receive response, disconnect
- Timeout handling per command (10 second default)

**Test criteria:**
- Test WebSocket connection to mock CDP server ✓
- Test each command sends correct CDP JSON and parses response ✓
- Test timeout triggers error after 10 seconds ✓
- Test connection failure returns clear error ✓

**Deliverables:**
- CDP backend for Chrome-family browsers, fully tested ✓

**Built:**
- `JARVIS/Tools/Browser/CDPTypes.swift` — `CDPError` enum (Error, Equatable; 8 cases), `CDPTarget` struct (Sendable, Equatable, Decodable)
- `JARVIS/Tools/Browser/CDPTransport.swift` — `CDPTransport` protocol abstracting WebSocket send/receive for testability
- `JARVIS/Tools/Browser/CDPDiscovery.swift` — `CDPDiscovering` protocol + `CDPDiscoveryImpl` struct; HTTP GET to `http://localhost:{port}/json`, decodes `[CDPTarget]`, `findPageTarget` filters to type=="page"
- `JARVIS/Tools/Browser/CDPBackendProtocol.swift` — `CDPBackendProtocol` with 9 methods (connect, disconnect, isConnected, navigate, evaluateJS, findElement, clickElement, typeInElement, getText, getURL)
- `JARVIS/Tools/Browser/CDPBackendImpl.swift` — `final class CDPBackendImpl: CDPBackendProtocol, @unchecked Sendable`. NSLock-protected request dictionary, atomic nextId, background reader Task, 10s command timeout with race-free continuation cleanup. JS string escaping for selectors/text. Logs via Logger.cdp. Enables Runtime+Page domains on connect.
- `JARVIS/Tools/Browser/URLSessionCDPTransport.swift` — Production `CDPTransport` backed by `URLSessionWebSocketTask`. NSLock-protected task reference.
- `JARVIS/Shared/Logger.swift` — Added `Logger.cdp` subsystem
- `Tests/Helpers/MockCDPTransport.swift` — AsyncStream-based mock; `enqueueResponse(id:result:)`, `enqueueErrorResponse(id:message:)`, `shouldFailConnect`, call recording
- `Tests/Helpers/MockCDPDiscovery.swift` — Configurable targets list, `shouldThrow`, call count recording
- `Tests/Helpers/MockCDPBackend.swift` — Full mock of `CDPBackendProtocol` with configurable results and errors per method; prepared for M015
- `Tests/ToolTests/CDPDiscoveryTests.swift` — 6 tests using `MockCDPURLProtocol` (local to this file)
- `Tests/ToolTests/CDPBackendTests.swift` — 18 tests using MockCDPTransport + MockCDPDiscovery

**Total tests: 454 (was 429, added 25)**

**Decisions:**
- `CDPTypes.swift` contains no `CDPBackendProtocol` to keep `protocol CDPBackendProtocol` in its own file as planned; `CDPTypes` is the shared foundation.
- `MockCDPURLProtocol` defined inline in `CDPDiscoveryTests.swift` (not a shared helper) — avoids naming conflict with `MockURLProtocol` in `APIClientTests.swift` which is in the same test module.
- `evaluateJS` converts `JSONValue.bool` → `"true"/"false"` explicitly; `JSONValue` string interpolation would produce `"bool(true)"` which breaks `findElement`'s string comparison.
- Timeout races handled: both the timeout Task and the background reader attempt `pendingRequests.removeValue(forKey:id)` under the same NSLock; only the one that succeeds gets to resume the continuation.
- `connectedBackend` helper in tests pre-enqueues responses for id=1 (Runtime.enable) and id=2 (Page.enable) so tests start from a clean state with id counter at 3.
- `URLSessionCDPTransport` is `final class @unchecked Sendable` with NSLock — matches the `AnthropicProvider` pattern. Not unit tested (requires real WebSocket server).

**Xcode build steps for owner:**
1. Open terminal: `cd /Users/aarontaylor/JARVIS`
2. Open project: `open JARVIS.xcodeproj`
3. Press **Cmd+B** — "Build Succeeded"
4. Press **Cmd+U** — 454 tests, all green
5. No new UI — CDP backend is service infrastructure (tools come in M015)
6. To test with real Chrome: launch Chrome with `open -a "Google Chrome" --args --remote-debugging-port=9222`, then the CDP backend can connect to it

---

### M015: AppleScript Backend (Safari) + Browser Tools `[x]`

**What to build:**
- `AppleScriptBackend` — control Safari via NSAppleScript
- Commands: navigate to URL, get current URL, get page text, run JavaScript
- `BrowserRouter` — routes to CDP or AppleScript based on frontmost browser
- Browser tools (all route through BrowserRouter):
  - `browser_navigate` — go to URL
  - `browser_get_url` — get current URL
  - `browser_get_text` — get page text content
  - `browser_find_element` — find element by CSS selector or text
  - `browser_click` — click an element
  - `browser_type` — type into an element

**Test criteria:**
- AppleScript: test correct AppleScript generated for each command ✓
- BrowserRouter: test routes to CDP for Chrome, AppleScript for Safari ✓
- Each browser tool: test with valid and invalid arguments ✓
- Integration: fixture test where Claude navigates and interacts with a page ✓

**Deliverables:**
- Safari support via AppleScript ✓
- 6 unified browser tools ✓
- Browser control complete ✓

**Built:**
- `JARVIS/Tools/Browser/BrowserBackend.swift` — `BrowserBackend` protocol (7 high-level browser commands)
- `JARVIS/Tools/Browser/BrowserError.swift` — `BrowserError` enum (noBrowserDetected, unsupportedBrowser, scriptFailed, navigationFailed)
- `JARVIS/Tools/Browser/AppleScriptBackend.swift` — Safari control via NSAppleScript with closure-injected script runner for testing
- `JARVIS/Tools/Browser/BrowserRouter.swift` — Routes to AppleScript (Safari) or CDP (Chromium); auto-connects CDP on first use; `CDPBrowserBackendAdapter` adapts navigate return type
- `JARVIS/Tools/BuiltIn/BrowserNavigateTool.swift` — `browser_navigate` (.caution)
- `JARVIS/Tools/BuiltIn/BrowserGetURLTool.swift` — `browser_get_url` (.safe)
- `JARVIS/Tools/BuiltIn/BrowserGetTextTool.swift` — `browser_get_text` (.safe, supports max_length truncation)
- `JARVIS/Tools/BuiltIn/BrowserFindElementTool.swift` — `browser_find_element` (.safe, CSS selector + text search)
- `JARVIS/Tools/BuiltIn/BrowserClickTool.swift` — `browser_click` (.caution)
- `JARVIS/Tools/BuiltIn/BrowserTypeTool.swift` — `browser_type` (.caution)
- `Tests/Helpers/MockBrowserBackend.swift` — Full mock with configurable results/errors and call recording
- `Tests/ToolTests/AppleScriptBackendTests.swift` — 11 tests for AppleScript generation and escaping
- `Tests/ToolTests/BrowserRouterTests.swift` — 10 tests for routing logic and CDP connection management
- `Tests/ToolTests/BrowserToolTests.swift` — 36 tests for all 6 browser tools
- `Tests/IntegrationTests/BrowserToolsIntegrationTests.swift` — 3 full-loop orchestrator tests
- Modified `BuiltInToolRegistration.swift` — added `registerBrowserTools(in:backend:)`
- Modified `ChatViewModel.swift` — wires BrowserRouter with real backends at startup

**Notes:**
- Safari requires "Automation" permission in System Settings → Privacy & Security → Automation. macOS will prompt on first use.
- Chrome must be launched with `--remote-debugging-port=9222` for CDP to work. If not, the tool returns a clear error.
- Firefox and unknown browsers return `BrowserError.unsupportedBrowser` (not a crash, just an error result).
- Total tests: **514** (was 454)

---

### M016: Session File Logger `[x]`

**What to build:**
- `SessionLogging` protocol — logs every turn of a conversation to a human-readable file
- `FileSessionLogger` — writes timestamped session traces to `~/Library/Logs/JARVIS/session-DATE.txt`
- `NullSessionLogger` — no-op implementation for tests/when logging is disabled
- Inject into `OrchestratorImpl` so every user message, thinking round, tool call/result, assistant response, and metrics are logged

**Test criteria:**
- Test that `FileSessionLogger` creates a log file on init ✓
- Test that each `log*` method appends to the file ✓
- Test that `NullSessionLogger` is a safe no-op ✓
- Integration: orchestrator round-trip produces expected session log entries ✓

**Deliverables:**
- Full session trace logging for debugging and analysis ✓

**Built:**
- `JARVIS/Shared/SessionLogger.swift` — `SessionLogging` protocol, `NullSessionLogger`, `FileSessionLogger` (thread-safe, timestamped, truncates long outputs)
- `Tests/Helpers/MockSessionLogger.swift` — Mock with call recording for tests
- `Tests/IntegrationTests/SessionLoggerIntegrationTests.swift` — 4 integration tests
- Modified `JARVIS/Core/OrchestratorImpl.swift` — injected `sessionLogger` dependency
- Modified `JARVIS/Shared/Logger.swift` — added `Logger.session`
- Total tests: **573** (was 514)

---

## Phase 4 — Voice Interface

JARVIS can hear you and talk back.

### M017: Wake Word Detection `[x]`

**What to build:**
- `WakeWordDetector` — integrates Picovoice Porcupine SDK
- Always-listening mode (microphone, <1% CPU)
- Configurable wake phrase (default: "Hey JARVIS")
- Callbacks: onWakeWordDetected, onError
- Start/stop/pause methods
- Microphone permission check and prompt
- Settings UI: enable/disable, change wake phrase

**Test criteria:**
- Test start/stop/pause lifecycle ✓
- Test permission check ✓
- Test callback fires (mock Porcupine) ✓
- Test CPU usage stays under 2% during listen mode (manual check — Porcupine is designed for <1%)

**Deliverables:**
- Working wake word detection ✓
- Settings integration ✓

**Built:**
- `JARVIS/Voice/WakeWordDetecting.swift` — `WakeWordDetecting` protocol + `WakeWordError` enum
- `JARVIS/Voice/AudioInputProviding.swift` — `AudioInputProviding` protocol for mic capture abstraction
- `JARVIS/Voice/WakeWordEngine.swift` — `WakeWordEngine` protocol for Porcupine abstraction
- `JARVIS/Voice/MicrophonePermission.swift` — `MicrophonePermissionChecking` protocol + `SystemMicrophonePermission`
- `JARVIS/Voice/WakeWordDetectorImpl.swift` — core detector logic (protocol-injected, fully testable)
- `JARVIS/Voice/AVAudioEngineInput.swift` — real mic capture via `AVAudioEngine` with 16kHz Int16 conversion
- `JARVIS/Voice/PorcupineEngine.swift` — thin C-API wrapper over vendored `PvPorcupine.framework`
- `JARVIS/UI/SettingsView/WakeWordSettingsView.swift` — toggle, access key entry, status label
- `JARVIS/Vendor/Porcupine/` — macOS universal `PvPorcupine.framework` + `porcupine_params.pv` + `jarvis_mac.ppn`
- `JARVIS/App/AppDelegate.swift` — wires detector on launch; requests microphone permission
- `Tests/VoiceTests/WakeWordDetectorTests.swift` — 9 unit tests
- `Tests/VoiceTests/AVAudioEngineInputTests.swift` — 3 state-machine tests
- `Tests/UITests/WakeWordSettingsViewTests.swift` — 2 tests
- `Tests/IntegrationTests/WakeWordIntegrationTests.swift` — 3 integration tests
- `Tests/Helpers/MockAudioInput.swift`, `MockWakeWordEngine.swift`, `MockMicrophonePermission.swift`

**Notes:**
- Porcupine SPM package is iOS-only; used macOS fallback: vendored `PvPorcupine.framework` built from
  `lib/mac/{arm64,x86_64}/libpv_porcupine.dylib` (universal binary via `lipo`).
- Wake phrase is fixed as "Hey JARVIS" (`jarvis_mac.ppn`). Custom phrases require Picovoice Console training (out of scope).
- Access key stored in Keychain under `"picovoice_access_key"`. User pastes key in WakeWordSettingsView.
- AVAudioEngineInput converts hardware audio (typically 48kHz Float32) → 16kHz Int16 mono via `AVAudioConverter`.
- 566 tests pass total.

---

### M018: Settings Window `[ ]`

**What to build:**
- `SettingsView.swift` — main settings window with a `TabView` (sidebar style on macOS). Wired into `JARVISApp.swift` via the `Settings` scene so Cmd+, opens it.
- **General tab** (`GeneralSettingsView.swift`) — app appearance (light/dark/system), launch at login toggle, global keyboard shortcut picker (using KeyboardShortcuts).
- **API Keys tab** (`APIKeysSettingsView.swift`) — secure fields for: Claude API key, Picovoice access key, Deepgram API key. All stored in Keychain via `KeychainHelper`. Show saved/missing status per key.
- **Voice tab** — reuse existing `WakeWordSettingsView.swift` (already built in M017). Add future placeholders for STT/TTS provider selection.
- **About tab** (`AboutSettingsView.swift`) — app version, build number, links to project repo. Sparkle "Check for Updates" button.
- Wire the `Settings` scene in `JARVISApp.swift` to show `SettingsView` instead of `EmptyView`.

**Test criteria:**
- Settings window opens via Cmd+, (manual verification by owner)
- API keys round-trip through Keychain: save → quit → reopen → keys still present (unit test `KeychainHelper` already covered in M002; add view-model tests)
- Each tab renders without crash (SwiftUI preview + unit tests on view models)
- Toggling "launch at login" updates `SMAppService` registration (unit test with mock)

**Deliverables:**
- Full settings window with 4 tabs (General, API Keys, Voice, About)
- Owner can paste Picovoice access key and Claude API key from the Settings UI
- All secrets stored exclusively in Keychain (no UserDefaults for keys)

---

### M019: Speech-to-Text (Deepgram) `[ ]`

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

### M020: Text-to-Speech (Deepgram) `[ ]`

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

### M021: MCP Client `[ ]`

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

### M022: MCP Server Manager + Integration `[ ]`

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

### M023: Conversation Persistence `[ ]`

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

### M024: Episodic Memory `[ ]`

**What to build:**
- `MemoryStore` — SQLite database for memories
- At conversation end: send conversation to Claude with "summarise this and extract key user facts"
- Store: session summary, extracted facts, timestamp
- At conversation start: retrieve recent and relevant memories, inject into system prompt
- Relevance: keyword matching on facts (full vector search comes later in M030)
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

### M025: Context Compression `[ ]`

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

### M026: Task Manager (Long-Running Workflows) `[ ]`

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

### M027: Personality System `[ ]`

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

### M028: Settings and Onboarding (Polish) `[ ]`

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

### M029: Ambient Awareness `[ ]`

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

### M030: Self-Built Tools `[ ]`

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

### M031: Vector Memory (sqlite-vec) `[ ]`

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

### M032: Phone Notifications for Approvals `[ ]`

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

### M033: Security Audit `[ ]`

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

### M034: Auto-Updates and Distribution `[ ]`

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

### M035: Beta Release `[ ]`

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
