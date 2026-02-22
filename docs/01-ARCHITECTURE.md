# JARVIS — Architecture

## The Core Loop

Everything JARVIS does follows one loop:

```
User input (voice or text)
  |
  v
Orchestrator builds a message:
  - System prompt (personality + capabilities + available tools)
  - Memory context (relevant things JARVIS remembers about the user)
  - Conversation history (recent messages)
  - The user's new message
  |
  v
Sends to Claude API (Anthropic Messages API with tool_use)
  |
  v
Claude responds with either:
  (a) Text response --> display/speak it, done
  (b) tool_use blocks --> continue below
  |
  v
For each tool_use block:
  1. ToolRegistry validates the call (does tool exist? valid args?)
  2. PolicyEngine checks safety (safe/caution/dangerous)
  3. If confirmation needed --> show dialog, wait for user
  4. Execute the tool
  5. Package result as tool_result
  |
  v
Send all tool_results back to Claude
  |
  v
Claude responds again (may request more tools or give final answer)
  |
  v
Repeat until Claude sends a text response (stop_reason: end_turn)
```

## Layer Diagram

```
┌─────────────────────────────────────────────┐
│                 UI Layer                      │
│  FloatingWindow / ChatView / SettingsView     │
│  ConfirmationDialog / StatusIndicator         │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────┴──────────────────────────┐
│              Voice Layer                      │
│  WakeWordDetector (Porcupine)                │
│  SpeechInput (Deepgram STT)                  │
│  SpeechOutput (Deepgram TTS)                 │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────┴──────────────────────────┐
│           Orchestrator Layer                  │
│  Orchestrator (the main loop)                │
│  TaskManager (long task decomposition)        │
│  ContextBuilder (system prompt + memory)      │
└──────────────────┬──────────────────────────┘
                   │
         ┌─────────┴─────────┐
         │                   │
┌────────┴───────┐  ┌───────┴────────┐
│  Claude API     │  │  Policy Engine  │
│  (ModelProvider) │  │  (safety gate)  │
└────────────────┘  └───────┬────────┘
                            │
┌───────────────────────────┴─────────────────┐
│              Tool Layer                       │
│  ToolRegistry (central dispatch)              │
│    │                                          │
│    ├── Built-in tools                         │
│    │   app_open, file_search, system_info,    │
│    │   clipboard_read, clipboard_write         │
│    │                                          │
│    ├── Computer Control tools                 │
│    │   get_ui_state (AX tree)                 │
│    │   ax_action (click, type, focus by ref)  │
│    │   ax_find (search for elements)          │
│    │   keyboard_shortcut (Cmd+C etc)          │
│    │   screenshot (fallback only)             │
│    │   mouse_click (fallback only)            │
│    │                                          │
│    ├── Browser tools                          │
│    │   browser_navigate, browser_click,        │
│    │   browser_type, browser_get_text,          │
│    │   browser_find_element, browser_get_url    │
│    │                                          │
│    └── MCP tools (dynamic, from plugins)      │
│        google_calendar, github, slack, etc.    │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────┴──────────────────────────┐
│            Memory Layer                       │
│  MemoryStore (SQLite)                         │
│    - Episodic (session summaries)             │
│    - Semantic (user facts, preferences)       │
│    - Vector search (sqlite-vec, later phase)  │
│  ConversationStore (encrypted history)        │
└─────────────────────────────────────────────┘
```

## Component Details

### Orchestrator

The brain's handler. It does NOT make decisions — Claude makes decisions. The Orchestrator just manages the conversation loop:

- Builds the full message payload (system prompt, history, tools)
- Sends to Claude via ModelProvider
- Receives response, checks stop_reason
- If `tool_use`: dispatches to ToolRegistry, collects results, sends back
- If `end_turn`: returns final text to UI
- Enforces round limits and timeouts (dynamic based on task complexity)
- Manages the context lock (which app we're working with)
- Logs every step via structured logging

**Round limits (dynamic):**
- Quick tasks: 10 rounds, 60 seconds
- Medium tasks: 30 rounds, 5 minutes
- Complex tasks: 100 rounds, 30 minutes
- Background workflows: 500 rounds, no time limit, with checkpointing

Claude self-classifies task complexity at the start. The Orchestrator adjusts limits accordingly.

### ModelProvider (Protocol)

```swift
protocol ModelProvider {
    func send(messages: [Message], tools: [ToolDefinition]) async throws -> Response
    func sendStreaming(messages: [Message], tools: [ToolDefinition]) -> AsyncStream<StreamEvent>
    func abort()
}
```

Only one real implementation: `AnthropicProvider`. This calls the Claude Messages API over HTTPS.

A `MockModelProvider` exists for testing. It returns pre-recorded responses from JSON fixtures.

### ToolRegistry

Central registry of all tools. Every tool is registered with:
- **ID** (string, snake_case): `app_open`, `get_ui_state`, `browser_navigate`
- **Definition**: name, description, parameters schema, risk level
- **Executor**: the actual code that runs the tool

The registry handles:
1. **Registration** — tools register at app startup (built-in) or runtime (MCP)
2. **Validation** — checks that Claude's tool call has valid arguments
3. **Dispatch** — routes to the right executor
4. **Result packaging** — wraps results in standard format

MCP tools register dynamically when MCP servers connect. They appear to Claude identically to built-in tools.

### PolicyEngine

Categorises every action and enforces safety:

| Risk Level | Examples | Level 0 (Ask All) | Level 1 (Smart) | Level 2 (Full Auto) |
|------------|---------|-------------------|-----------------|---------------------|
| Safe | Read file, get system info, list apps | Ask | Auto | Auto |
| Caution | Open app, click button, type text, navigate browser | Ask | Auto | Auto |
| Dangerous | Delete file, run terminal command, send email, make purchase | Ask | **Ask** | Auto |
| Destructive | Delete folder, format disk, bulk delete | Ask | Ask | **Ask** |

Level 1 is the default. Destructive actions ALWAYS ask, regardless of level.

### Computer Control — The AX-First Approach

**Primary path (Accessibility API):**

Every Mac app has a hidden tree of UI elements:

```
Safari (application)
  └── Main Window
      ├── Toolbar
      │   ├── Back button (@e1)
      │   ├── Forward button (@e2)
      │   └── URL field (@e3) — value: "https://google.com"
      └── Web Content
          ├── Link "Gmail" (@e4)
          ├── Link "Images" (@e5)
          └── Search field (@e6)
```

`get_ui_state` reads this tree and returns it to Claude as text. Each element gets a ref tag (@e1, @e2, etc.).

`ax_action` performs actions on elements: press @e1 (click Back), set_value @e3 "github.com" (type in URL field), focus @e6 (click into search field).

`ax_find` searches for elements: find button titled "Submit", find text field with value containing "email".

**Why this is better than screenshots:** Instant (< 100ms vs 3-8 seconds), free ($0 vs $0.02-0.06 per screenshot), and near-perfect accuracy (targeting a known element vs guessing pixel coordinates).

**Fallback paths (in order):**
1. AppleScript — for apps with good scripting support (Safari, Mail, Finder, Calendar)
2. Keyboard shortcuts — Cmd+C, Cmd+V, Cmd+T, etc.
3. Code-as-action — generate and execute a script for the task
4. Screenshot + Vision — take a screenshot, send to Claude vision, get coordinates, click. Last resort.

**Context lock:**
When `get_ui_state` runs, it records the target app's bundle ID and process ID. Before every subsequent input action (click, type, etc.), the Orchestrator verifies the same app is still frontmost. If not, it stops and tells Claude "target app lost focus." This prevents typing in the wrong app.

### Browser Control

Two layers:
1. **Browser chrome** (address bar, tabs, bookmarks) — controlled via AX
2. **Web page content** (the actual website) — controlled via browser-specific protocols

| Browser | Web Content Method | Fallback |
|---------|-------------------|----------|
| Chrome, Edge, Arc, Brave | CDP (Chrome DevTools Protocol) | AppleScript, then AX |
| Safari | AppleScript | AX |
| Firefox | CDP (partial) | AX |
| Unknown | AX only | Screenshot |

A `BrowserDetector` automatically identifies the frontmost browser and selects the right backend. The tool interface is identical regardless of backend — Claude uses the same `browser_navigate`, `browser_click`, etc. tools.

### Voice Pipeline

```
[Always running]                    [On demand]
Microphone
  → Porcupine (wake word, <1% CPU)
  → "Hey JARVIS" detected
  → Deepgram STT (streaming WebSocket, <300ms)
  → Text arrives in real-time
  → Sent to Orchestrator
  → Claude processes
  → Response streams back
  → Deepgram TTS (streaming, ~90ms first audio)
  → Audio plays as it arrives
```

**Key: everything streams.** We don't wait for you to finish speaking before starting transcription. We don't wait for Claude to finish its whole response before starting speech. This pipelining makes it feel like a real conversation.

Offline fallback: Apple SFSpeechRecognizer (STT) + AVSpeechSynthesizer (TTS). Lower quality but works without internet.

### Memory System

**Tier 1 — Working Memory (in conversation)**
The last N messages in the current conversation. Already in the context window. No persistence needed.

**Tier 2 — Episodic Memory (session summaries)**
When a conversation ends, JARVIS generates a summary and extracts key facts:
- "User booked ANA flight to Tokyo for March 15th"
- "User prefers window seats"
- "User's boss is Sarah Chen"

Stored in SQLite. Retrieved by relevance at the start of each new conversation.

**Tier 3 — Semantic Memory (vector search, later phase)**
Embeddings of all memories stored via sqlite-vec. Allows finding relevant memories by meaning ("What restaurant did I like?" finds a memory about "loved the ramen at Ichiran" even though the words are different).

### Ambient Awareness (later phase)

Background observers that run quietly:
- **Clipboard observer** — detects URLs, addresses, code, errors. Offers contextual actions.
- **Calendar observer** — upcoming events. Proactive reminders.
- **App switch observer** — context-aware suggestions based on what app you're using.
- **Idle observer** — offers help when you've been inactive.

All non-intrusive (subtle indicators, never blocking popups), rate-limited, and individually toggle-able in settings.

### Task Manager (for long-running workflows)

Handles tasks that take minutes or hours:

1. Claude decomposes the task into numbered steps
2. Each step executes as a separate orchestrator turn
3. After each step: save checkpoint to disk (step number, accumulated results, partial state)
4. Progress reported to UI ("Step 3/7: Comparing flight prices...")
5. If app closes/crashes: resume from last checkpoint on next launch
6. If a step needs user approval: pause, notify user (and optionally ping phone)

### Security Layers

1. **API keys** — macOS Keychain only. Encrypted by hardware.
2. **No shell injection** — Process API with argument arrays, never string interpolation.
3. **Path restrictions** — PolicyEngine blocks system paths and traversal.
4. **Action approval** — Dangerous/destructive actions always require confirmation.
5. **Kill switch** — Instant stop, no confirmation, cancels everything.
6. **Encrypted conversations** — Chat history encrypted at rest on disk.
7. **Round limits** — Prevents infinite loops.
8. **Context lock** — Prevents actions on wrong app.
9. **Input sanitisation** — All tool arguments cleaned before execution.
10. **Structured logging** — Full audit trail of every action.
