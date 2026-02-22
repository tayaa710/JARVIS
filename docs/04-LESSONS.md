# JARVIS — Lessons from v1 (aiDAEMON)

## Context

v1 was 17,300 lines of Swift across 44 files, built over ~60 milestones. It was functional — the core agent loop, accessibility-first computer control, browser automation, MCP integration, and voice I/O all worked. But it had accumulated significant technical debt and several persistent bugs.

This document captures what we learned so v2 doesn't repeat the mistakes.

## What Worked (Keep These Patterns)

### 1. Anthropic tool_use API
The reactive loop (Claude returns `tool_use`, we execute, send `tool_result` back) is exactly right. Claude decides the next step based on results, not a pre-computed plan. This matches Anthropic's own recommendation for building agents. **Keep this pattern unchanged.**

### 2. Accessibility-first computer control
Reading the AX tree gives structured, labeled UI elements. Claude targets by ref (@e1, @e2) instead of guessing pixel coordinates. This is faster (<100ms vs 3-8s), free ($0 vs $0.02-0.06 per screenshot), and more accurate (~99% vs ~70-80%). Industry research confirms this is the superior approach for macOS. **Keep this as the primary computer control method.**

### 3. Foreground context lock
Recording the target app's bundle ID and PID when `get_ui_state` runs, then verifying before every input action. Prevents typing in the wrong app. This is a safety-critical feature. **Keep this pattern unchanged.**

### 4. Autonomy levels
L0/L1/L2 with destructive actions always requiring confirmation regardless of level. This matches industry best practices (every successful agent system has human-in-the-loop for dangerous actions). **Keep this pattern unchanged.**

### 5. MCP integration
Tools auto-register from MCP servers, Claude sees them identically to built-in tools. With 97M+ monthly MCP SDK downloads, this is the correct protocol. **Keep this approach.**

### 6. Documentation
The docs (threat model, architecture, milestones) were consistently the strongest part of the project. They allowed new AI sessions to understand the project quickly. **Keep thorough documentation as a core practice.**

## What Broke (Fix These in v2)

### 1. Zero automated tests
v1 had no unit tests, no integration tests, nothing automated. Every bug required the owner to manually test, find the issue, start a new AI conversation, and fix it. This was the single biggest source of wasted time and money.

**v2 fix:** Every feature requires tests. Write the test first. Run all tests before marking anything done. CI runs tests on every push.

### 2. Local model (LlamaSwift) was a nightmare
The LlamaSwift dependency caused constant build issues. API changes broke things. The local model (LLaMA 3.1 8B) was too dumb for tool use anyway. The model routing logic added complexity that never worked reliably (the "Always Local" setting was broken for weeks).

**v2 fix:** No local model. Claude API only. One brain, one integration, no routing. Revisit local AI when Apple's Foundation Models framework ships.

### 3. Files grew too large
CDPBrowserTool.swift hit 1,479 lines. SettingsView.swift hit 1,180 lines. Orchestrator.swift hit 890 lines. Large files are hard for both humans and AI to work with effectively. AI agents read the entire file to understand context — bigger file = more tokens = more cost.

**v2 fix:** Hard limit of 500 lines per file. Split early. The file structure is designed with granular directories from the start.

### 4. Mixed async patterns
Some code used completion handlers (callbacks), some used async/await, some used Combine. Bridging between them with `withCheckedContinuation` added complexity and potential bugs.

**v2 fix:** Pure async/await everywhere. No completion handlers. No Combine for async flows (Combine only for SwiftUI bindings).

### 5. No structured logging
v1 had 96 scattered `NSLog` statements. When something went wrong, there was no way to trace what happened. Debugging required adding more print statements, rebuilding, and testing again.

**v2 fix:** os.log with subsystems from day 1. Every tool call logged. Every API request logged. Every policy decision logged.

### 6. Architecture churn
Without a locked plan, decisions changed frequently. The local model approach was redesigned 3 times. The tool system was refactored twice. Each change cost money and introduced bugs.

**v2 fix:** Architecture is locked in CLAUDE.md. The architect (Opus) plans before the builder (Sonnet) codes. No mid-milestone architecture changes.

### 7. Legacy code never cleaned up
CommandParser.swift, CommandValidator.swift, CommandRegistry.swift were marked "legacy" but never removed. This confused AI agents working on the project ("should I use ToolRegistry or CommandRegistry?").

**v2 fix:** No dead code. If something is unused, delete it immediately. No "legacy fallback" patterns.

### 8. Force unwraps everywhere
v1 had 295 force unwraps (`!`, `as!`, `try!`). Many were in tool executors where malformed arguments could cause crashes.

**v2 fix:** No force unwraps in production code. The only exception is hardcoded constants (URLs, known-good values).

### 9. Conservative round limits
10 rounds max and 90 second timeout were too restrictive for complex tasks. Researching flights, comparing options, and booking would easily exceed both limits.

**v2 fix:** Dynamic limits based on task complexity. Quick tasks: 10 rounds. Complex tasks: 100 rounds. Background workflows: 500 rounds with checkpointing.

### 10. Unencrypted conversation storage
Chat history was saved as plain JSON. Anyone with access to the Mac could read all conversations.

**v2 fix:** Conversation history encrypted at rest with AES-GCM. Key stored in Keychain.

## What We Learned from Industry Research

### Successful projects
- **OpenClaw** (145K GitHub stars): Messaging-first personal AI agent. Proved massive demand. Input normalisation pattern is good.
- **Claude Code**: Single-threaded loop, flat message history, no vector DB (just regex search). Simplicity wins.
- **CrewAI** ($18M funding, 60M+ executions/month): Role-based multi-agent collaboration works when a single agent isn't enough.
- **Open Interpreter**: Code-as-action (generate scripts) is a good fallback when AX and screenshots both fail.

### Failed projects
- **Rabbit R1** (95% abandonment): Don't build a new device. Enhance existing ones.
- **Humane AI Pin** (bricked): Same lesson. Also: voice-only isn't enough (only 13% prefer it).
- **AutoGPT**: Fully autonomous without guardrails → infinite loops and runaway costs. Always have limits and human-in-the-loop.
- **Adept AI** (absorbed by Amazon): Even state-of-the-art screenshot-based agents only complete 25-40% of complex workflows. AX-first is the better path.

### Key principles from Anthropic's own research
1. Start simple — composable patterns over complex frameworks
2. Context engineering > prompt engineering — design the full environment
3. Send errors back to the LLM — let Claude adapt when tools fail
4. Structured progress tracking — checkpoint files for long tasks
5. Trace everything — full audit trail is non-negotiable
