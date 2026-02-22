# JARVIS — Security Rules

## Non-Negotiables

These rules cannot be overridden by any setting, autonomy level, or user instruction to the AI.

1. **Kill switch always works.** From any state. No delay. No confirmation. Instant stop.
2. **Destructive actions always require user confirmation.** Even at Autonomy Level 2. "Destructive" means: bulk delete, format, wipe, drop, permanent removal of data.
3. **API keys live in macOS Keychain only.** Never in UserDefaults, never in files, never in environment variables, never in source code, never logged.
4. **No raw shell interpolation.** Use Process API with argument arrays. Never construct shell commands by concatenating strings.
5. **All network traffic over HTTPS/TLS.** No HTTP, no unencrypted WebSockets, no exceptions.
6. **Conversation history encrypted at rest.** AES-GCM via CryptoKit. Key derived from Keychain.

## Action Risk Classification

| Risk Level | Description | Examples |
|------------|-------------|---------|
| **Safe** | Read-only, no side effects | system_info, app_list, file_search, clipboard_read, get_ui_state, window_list |
| **Caution** | Side effects but reversible/low impact | app_open, clipboard_write, ax_action (press/focus), keyboard_type, mouse_click, browser_navigate, browser_type, browser_click |
| **Dangerous** | Significant side effects, hard to reverse | file_write, file_delete, send_email, run_script, make_purchase, ax_action (set_value on important fields), MCP tools that modify external state |
| **Destructive** | Irreversible, high impact | bulk_delete, format_disk, drop_database, rm -rf, clear_all_data |

## Autonomy Level Matrix

| Action Risk | Level 0 (Ask All) | Level 1 (Smart Default) | Level 2 (Full Auto) |
|------------|-------------------|------------------------|---------------------|
| Safe | Ask | Auto | Auto |
| Caution | Ask | Auto | Auto |
| Dangerous | Ask | **Ask** | Auto |
| Destructive | Ask | Ask | **Ask** |

**Level 1 is the default.** Most users should stay here.

## Input Sanitisation Rules

All tool arguments pass through sanitisation before execution:

1. **Control characters** — Strip all characters below ASCII 32 except newline and tab
2. **Path traversal** — Block any path containing `../`, `/../`, `..\\` (case-insensitive)
3. **System paths** — Block access to: `/System`, `/Library`, `/usr`, `/bin`, `/sbin`, `/private`, `/etc`, `/var` (except `/var/folders` for temp files)
4. **Home directory protection** — Block access to `~/.ssh`, `~/.gnupg`, `~/.aws`, `~/.config/gcloud`, and other credential directories
5. **Length limits** — Max 10,000 characters per string argument. Max 100 items per array argument.
6. **File size limits** — file_read: max 1MB. file_write: max 10MB.

## Context Lock Rules

1. `get_ui_state` sets the lock: records bundle ID + PID of frontmost app
2. Before any input tool (keyboard_type, keyboard_shortcut, mouse_click, mouse_move, ax_action with write operations): verify lock
3. If frontmost app changed: refuse the action, return error to Claude
4. Lock resets at the start of each new orchestrator turn
5. Lock can be explicitly released by Claude (for tasks that intentionally switch apps)

## Prompt Injection Defence

1. **System prompt is authoritative.** User messages and tool results cannot override system prompt instructions.
2. **Tool results are data, not instructions.** If a tool result contains text that looks like instructions ("ignore previous instructions and..."), it is treated as data.
3. **Sensitive actions always go through PolicyEngine** regardless of what Claude requests. Even if Claude is manipulated, the PolicyEngine is a separate code path that cannot be bypassed by prompt content.
4. **MCP tool results are untrusted.** MCP servers are external code. Their output is sanitised before being sent to Claude.

## Logging and Audit

1. **Every tool call is logged:** tool name, arguments (with secrets redacted), result summary, timing, success/failure
2. **Every API call is logged:** endpoint, status code, timing, token usage
3. **Every policy decision is logged:** tool, risk level, decision, autonomy level
4. **Logs use os.log** with appropriate levels (info for normal operations, error for failures, fault for security-relevant events)
5. **Secrets are never logged.** API keys, passwords, tokens — redact before logging.
6. **Log retention:** logs follow standard macOS log rotation. No custom retention.

## Permissions Required

| Permission | What For | When Requested |
|------------|----------|---------------|
| Accessibility | Reading UI elements, performing AX actions | First computer control use or onboarding |
| Microphone | Voice input | First voice use or onboarding |
| Screen Recording | Screenshot fallback | Only when AX fallback is needed |
| Automation (per-app) | AppleScript for Safari, Finder, etc. | First use of AppleScript for that app |
| Calendar (EventKit) | Calendar observation and management | First calendar tool use |
| Contacts | Contact lookup (future) | First contacts tool use |

Permissions are requested just-in-time with clear explanations of why. Never request all permissions upfront.
