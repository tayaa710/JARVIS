# JARVIS (aiDAEMON v2) — Agent Instructions

> This file is automatically read by Claude Code at the start of every conversation.
> It contains everything you need to know to work on this project.

## What This Project Is

A macOS-native AI assistant called JARVIS (internally "aiDAEMON"). Think Iron Man's JARVIS — you talk to your computer, it talks back, and it can do anything you can do on your Mac. It controls apps, browses the web, manages files, fills out forms, sends emails, books flights — anything. It learns about you over time and gets better the more you use it.

The owner does NOT code. All development is done by AI agents. The owner builds in Xcode, runs the app, and does light manual verification.

## Locked-In Architecture Decisions

These are final. Do not change or question these.

1. **Swift + SwiftUI only.** Native macOS app. No Electron, no Python, no hybrid.
2. **Claude API is the only brain.** No local LLM. No LlamaSwift. No on-device model.
3. **Anthropic tool_use API** for the agent loop. Claude returns `tool_use` content blocks, we execute them, send `tool_result` back. Reactive loop — Claude decides the next step based on results.
4. **Accessibility-first computer control.** macOS AXUIElement API gives a structured UI tree. Claude targets elements by ref (@e1, @e2). Screenshot+vision is the LAST fallback only.
5. **MCP (Model Context Protocol)** for plugin tools. Community-built tools plug in without custom code.
6. **No local model, no model routing.** One brain (Claude), one API. Simplicity over flexibility.
7. **Apple Swift Testing framework** for all tests. Not XCTest (except UI tests). Not Quick/Nimble.
8. **Deepgram** for speech-to-text and text-to-speech. Apple Speech as offline fallback only.
9. **Picovoice Porcupine** for wake word detection.
10. **sqlite-vec + FTS5** (single SQLite database) for memory/vector search when we get there.
11. **macOS 14.0+ minimum** (Sonoma). Drops legacy compatibility for cleaner APIs.
12. **Bundle ID:** com.aidaemon

## Development Rules (MANDATORY)

### Testing
- **Every feature requires automated tests.** No exceptions.
- **Write the test FIRST.** Watch it fail. Then write the code. Run the test. It passes. Move on.
- **Run the full test suite before declaring any milestone done.**
- **Mock the Claude API for integration tests.** Use a `MockModelProvider` that returns pre-recorded responses. Never hit the real API in tests.
- **Tests must be deterministic.** Same input, same result, every time.

### Code Quality
- **No file over 500 lines.** If a file approaches 500, split it before it gets there.
- **Pure async/await everywhere.** No completion handlers. No callback patterns. No Combine for async flows (Combine is fine for UI bindings only).
- **Protocol-first design.** Every major component has a protocol. This enables mocking and testing.
- **No force unwraps (`!`) in production code.** Use `guard let`, `if let`, or `??` with sensible defaults. The only exception is hardcoded constants like `URL(string: "https://api.anthropic.com")!`.
- **Structured logging with `os.log`.** Every tool call, every API request, every error. Use subsystems per component (e.g., `com.aidaemon.orchestrator`, `com.aidaemon.tools`).
- **No dead code.** If something is unused, delete it. No commented-out blocks, no legacy fallbacks.

### Architecture
- **One responsibility per file.** Orchestrator orchestrates. Tools execute. Providers provide.
- **All network calls go through a single `APIClient` layer.** This makes it easy to mock, log, and add retry logic in one place.
- **All tool execution goes through the `ToolRegistry`.** No direct tool calls from the Orchestrator.
- **All dangerous actions go through `PolicyEngine`.** No exceptions. No bypasses.
- **State lives in clearly defined stores.** No global mutable singletons. Pass dependencies via init.

### Workflow
- **Read 02-MILESTONES.md** to understand the current milestone scope.
- **Plan before coding.** If you are the architect (Opus), output a plan and stop. If you are the builder (Sonnet), follow the plan step by step.
- **When a milestone is done:** Update 02-MILESTONES.md to mark it complete. List what was built. Note any decisions. Provide Xcode build steps for the owner.
- **If you are stuck on something architectural, STOP.** Say "I need the architect for this" and describe the problem. Do not redesign architecture yourself.
- **Commit format:** `M[NUMBER]: Short description` (e.g., `M001: Project foundation and test infrastructure`)

### What NOT To Do (Lessons From v1)
- **Do NOT add a local LLM.** We tried it. LlamaSwift was a nightmare. Local models are too dumb for tool use. It's gone.
- **Do NOT mix async patterns.** v1 had completion handlers AND async/await AND Combine for async work. Pick one (async/await) and stick with it.
- **Do NOT let files grow big.** v1 had a 1,479-line file. That's unmaintainable. Split early.
- **Do NOT skip tests to save time.** v1 had zero automated tests. Every bug required expensive manual testing cycles. Tests save money.
- **Do NOT build features without updating docs.** v1's docs drifted from reality. Keep them in sync.
- **Do NOT use NSLog.** Use os.log with proper subsystems and log levels.
- **Do NOT store secrets anywhere except macOS Keychain.** Not UserDefaults, not files, not environment variables.

## Key Dependencies

| Package | What For | Source |
|---------|----------|--------|
| Sparkle | Auto-updates | `sparkle-project/Sparkle` (SPM) |
| KeyboardShortcuts | Global hotkeys | `sindresorhus/KeyboardShortcuts` (SPM) |
| Porcupine | Wake word detection | Picovoice SDK |

Keep dependencies minimal. Prefer Apple frameworks over third-party when possible.

## Project Structure

```
JARVIS/
  App/
    JARVISApp.swift          — App entry point
    AppDelegate.swift         — Lifecycle, menu bar, permissions
  Core/
    Orchestrator.swift        — The conversation loop
    ModelProvider.swift        — Protocol + Claude implementation
    ToolRegistry.swift         — Tool registration, validation, dispatch
    PolicyEngine.swift         — Safety levels, action approval
    TaskManager.swift          — Long-running task decomposition + checkpoints
  Tools/
    BuiltIn/                  — app_open, file_search, system_info, etc.
    ComputerControl/          — AX service, UI state, mouse, keyboard
    Browser/                  — CDP, AppleScript backends
    MCP/                      — MCP client, server manager
  Voice/
    WakeWordDetector.swift    — Porcupine integration
    SpeechInput.swift         — Deepgram STT
    SpeechOutput.swift        — Deepgram TTS
  Memory/
    MemoryStore.swift         — SQLite-based memory (episodic + semantic)
    ConversationStore.swift   — Encrypted conversation persistence
  UI/
    FloatingWindow.swift      — Main chat window
    ChatView.swift            — Chat interface
    SettingsView/             — Settings split into tabs (separate files)
    ConfirmationDialog.swift  — Dangerous action approval
  Shared/
    APIClient.swift           — Central HTTP client
    KeychainHelper.swift      — Secure key storage
    Logger.swift              — os.log wrapper with subsystems
    Extensions/               — Small Swift extensions
  Tests/
    CoreTests/                — Orchestrator, PolicyEngine, ToolRegistry tests
    ToolTests/                — Individual tool executor tests
    IntegrationTests/         — Full loop tests with mock provider
    Fixtures/                 — Recorded API responses for replay
```

## Terminology

For clarity across all docs and conversations:

- **Orchestrator** = The main loop. Takes user input, talks to Claude, executes tools, repeats until done.
- **Tool** = Something JARVIS can DO on the Mac (open app, click button, read file).
- **Tool call** = Claude saying "I want to use this tool with these arguments."
- **Tool result** = What happened when the tool ran ("Safari opened successfully").
- **AX / Accessibility** = The hidden structure of UI elements in every Mac app. Buttons, text fields, menus — all readable as a tree.
- **Element ref** = A tag like @e1, @e2 that identifies a specific UI element so Claude can say "click @e3."
- **Context lock** = A safety check that remembers which app we're working with and stops if the user switches away.
- **MCP** = Model Context Protocol. A standard for plug-in tools (Google Calendar, GitHub, Slack, etc.).
- **CDP** = Chrome DevTools Protocol. How we control web pages inside Chrome-family browsers.
- **System prompt** = Hidden instructions sent to Claude before every conversation that set JARVIS's personality and capabilities.
- **Policy engine** = The safety system that decides if an action is safe, needs caution, or is dangerous.
- **Checkpointing** = Saving progress to disk so long tasks can resume after interruption.

## Available Resources (YC Deals)

- **Anthropic Claude API** — Primary brain, best for agentic tool-use
- **Deepgram ($15K credits)** — Speech-to-text and text-to-speech
- **OpenAI ($2,500 credits)** — Embeddings (text-embedding-3-small) for memory system
- **AWS ($10K credits)** — Hosting for auto-update server, potential push notification backend
- **Firecrawl** — Web scraping/data extraction
- **xAI / Grok ($2,500 credits)** — Backup LLM if needed
- **Fireworks AI** — Fast inference, potential speed-optimised option
