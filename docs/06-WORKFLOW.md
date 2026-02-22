# JARVIS — Development Workflow

## The Two-Prompt System

Every milestone uses two prompts in two separate conversations.
- **Opus** plans (expensive but smart — one short conversation)
- **Sonnet** builds (cheap but capable — one longer conversation)

CLAUDE.md carries all the rules. The prompts only carry what's unique to the task. This keeps token costs low.

---

## Step-by-Step

### 1. Open Claude Code in the project folder

### 2. Switch to Opus
```
/model opus
```

### 3. Paste the Architect Prompt

```
Architect milestone M[NUMBER]. Plan only, no code.

Read CLAUDE.md, docs/02-MILESTONES.md (M[NUMBER]), and every file this milestone touches.

Output a numbered build checklist covering:
- Files to create/modify (full paths)
- What each file does (one sentence)
- Public APIs (function/type names, inputs, outputs)
- Tests for each file (test name + what it asserts)
- Step order (dependencies)
- Tricky decisions (pick one approach, explain why)

Flag anything unclear. Keep diffs minimal to milestone scope.
```

### 4. Review the Plan
- Ask questions, request changes
- Once happy, copy the final plan

### 5. Start a New Conversation

### 6. Switch to Sonnet
```
/model sonnet
```

### 7. Paste the Builder Prompt

```
Build milestone M[NUMBER]. Follow the plan exactly.

Read CLAUDE.md and docs/02-MILESTONES.md (M[NUMBER]).

Approved plan:
---
[PASTE PLAN HERE]
---

For each step: test first (should fail) → implement → test again (should pass) → next step. If blocked, STOP and report what you tried + exact error. Do not redesign.

After each step report: step title, files changed, test results.
When done: run full test suite, update 02-MILESTONES.md, give me xcodebuild commands.
```

### 8. Let It Build
- Approve permission prompts as they come
- If Sonnet gets stuck, see below

### 9. Build and Verify
- Run the xcodebuild command Sonnet gives you
- Do any manual checks Sonnet lists (should be minimal)
- Done — next milestone

---

## When Sonnet Gets Stuck

1. Copy the problem description
2. Start a new conversation
3. `/model opus`
4. Paste:

```
Builder is stuck on M[NUMBER]:

---
[PASTE PROBLEM + ERROR OUTPUT]
---

Read the relevant files. Give me a solution as a revised plan section I can hand back to the builder.
```

5. Take the solution to a new Sonnet conversation and continue

---

## Why the Prompts Are Short

CLAUDE.md already tells the AI:
- Test-first development
- No file over 500 lines
- No force unwraps
- Protocol-first design
- Structured logging
- No dead code
- Pure async/await
- Update docs when done

**You don't need to repeat these in the prompt.** The AI reads CLAUDE.md automatically. Every word you put in the prompt gets charged on every message in the conversation. Short prompt = same quality, much cheaper.

---

## Cost Management

- `/cost` — check current conversation spend
- **Start fresh when confused.** A new conversation re-reads CLAUDE.md cleanly. Cheaper than fighting a confused context.
- **Cap at ~40 messages.** If a build session gets long, finish the current step, start fresh for the rest.
- **Opus thinks, Sonnet does.** Never let Opus write lots of code. Never ask Sonnet to make architecture decisions.

---

## Quick Reference

```
NEW MILESTONE:
  /model opus → Architect Prompt → review plan → copy plan
  New conversation → /model sonnet → Builder Prompt → let it build
  Xcode build → verify → done

STUCK:
  New conversation → /model opus → describe problem → get fix
  New conversation → /model sonnet → continue with fix

COSTS:
  /cost              → check spend
  /model sonnet      → cheap (default)
  /model opus        → expensive (planning only)
  ~40 messages max   → start fresh after that
```
