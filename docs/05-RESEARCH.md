# JARVIS — Research Summary

This summarises the extensive research done in February 2026 before starting v2. Full details were discussed in the pre-v2 planning conversations.

## Technology Choices (Validated by Research)

### Platform: Swift + SwiftUI (Native macOS)
- **Why not Electron:** Electron adds 100-200MB RAM overhead and bundles Chromium. JARVIS doesn't need to render web content — it controls other apps. ChatGPT and Claude desktop use Electron because they're just chat UIs. JARVIS needs direct AX, CGEvent, and NSWorkspace access.
- **Why not Tauri:** Good for cross-platform, but JARVIS is macOS-only. Adds Rust + JS complexity without benefit.
- **Why not Python brain + Swift shell:** IPC overhead, deployment nightmare (bundling Python runtime), state synchronisation bugs. Every successful agent project picks ONE language for the brain and sticks with it.
- **Reference: Raycast** — Native Swift (AppKit) core with Node.js extensions via IPC. Core is native, extensions are sandboxed. Best macOS hybrid architecture reference.

### AI Brain: Claude API Only
- Claude models (Sonnet 4.5, Opus 4.6) dominate every agentic benchmark.
- Claude's native tool_use API is the cleanest tool-use protocol available.
- 200K+ token context window handles complex tasks.
- No local model: LLaMA 8B can't do reliable tool use. Apple Foundation Models (coming 2026) is the future local option.

### Testing: Apple Swift Testing Framework
- `@Test` macro cleaner than XCTest naming conventions
- `#expect` more expressive than `XCTAssertEqual`
- Parameterised tests built-in (critical for testing many tool inputs)
- Native async/await support
- Runs in parallel by default
- XCTest kept only for UI tests (XCUITest)

### Computer Control: AX-First
- AXUIElement API: structured tree, ~99% accurate, <100ms, $0
- Screenshot + Vision: flat pixels, ~70-80% accurate, 3-8s, $0.02-0.06
- Claude Computer Use and competitors complete only 25-40% of complex workflows with screenshots
- AX-first is the correct architecture, validated by industry performance data

### Voice: Porcupine + Deepgram
- **Wake word:** Picovoice Porcupine — on-device, Swift SDK, <1% CPU, custom wake phrases
- **STT:** Deepgram Nova-3 — streaming WebSocket, <300ms, excellent accuracy. $15K YC credits.
- **TTS:** Deepgram Aura-2 — streaming, ~90ms first audio, natural voice.
- **Alternative considered:** OpenAI Realtime API — single model but forces GPT-4o (can't use Claude as brain). Rejected.
- **Alternative considered:** ElevenLabs — best TTS quality but more expensive. Consider for future premium tier.
- **Offline fallback:** Apple SFSpeechRecognizer (STT) + AVSpeechSynthesizer (TTS)

### Memory: SQLite + sqlite-vec
- sqlite-vec: SQLite extension for vector search. Single file, no external process, SIMD-accelerated on Apple Silicon, ~1MB footprint.
- FTS5: SQLite's full-text search. Combine with sqlite-vec for hybrid retrieval.
- **Not FAISS:** 50MB footprint, Python-centric.
- **Not Chroma:** Client/server model, unnecessary for single-machine app.
- **Embeddings:** Apple NLEmbedding (free, on-device, 512-dim) or OpenAI text-embedding-3-small ($2,500 credits available).
- Claude Code uses NO vector DB — just search + LLM understanding. Start simple, add vectors later.

### MCP: Fully Adopted
- 97M+ monthly SDK downloads (Feb 2026)
- Backed by Anthropic, OpenAI, Google, Microsoft
- 2,800+ community servers
- November 2025 spec added async execution and enterprise features
- aiDAEMON should both CONNECT TO MCP servers and eventually EXPOSE ITSELF as an MCP server

## Competitive Landscape (Feb 2026)

| Competitor | Approach | JARVIS Advantage |
|-----------|----------|-----------------|
| **OpenClaw** | Messaging-first (WhatsApp, Telegram) | JARVIS is desktop-native with deep OS control |
| **Apple Intelligence** | On-device, assistive (not agentic) | JARVIS is agentic — executes multi-step workflows autonomously |
| **Claude Computer Use** | Screenshot-based pixel clicking | JARVIS uses AX (faster, cheaper, more accurate) |
| **Siri** | Command system (pre-built actions only) | JARVIS is a reasoning system (figures out novel tasks) |
| **Cursor / Claude Code** | Coding-focused agents | JARVIS controls the full OS, not just code |
| **OpenAI Operator** | Web automation only | JARVIS controls desktop apps, browser, voice, and more |

## Key Industry Insights

1. **AI should enhance existing devices, not replace them** (Rabbit R1 / Humane Pin failure)
2. **Single capable agent > multi-agent swarm** for most tasks (Claude Code, CrewAI findings)
3. **Structured data > screenshots** for computer control (AX > vision for macOS)
4. **Simplicity wins** — Claude Code uses no vector DB, flat message history, single-threaded loop
5. **Tests are cheaper than bug-fixing cycles** — every successful project has automated testing
6. **Voice complements but doesn't replace text/visual UI** (13% voice preference rate)
7. **Personality creates attachment** — users stay when the product has emotional connection
8. **Human-in-the-loop is non-negotiable** for dangerous actions (every production agent has this)
9. **Context engineering > prompt engineering** — design the full environment, not just the prompt
10. **Send errors to the LLM** — Claude adapts when it sees error messages. Best recovery strategy.
