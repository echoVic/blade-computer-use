# Blade Computer Use Design

## Goal

Build a small, open-source macOS computer-use implementation that can be installed in Codex and Claude Code and configured in Orca. The shared runtime boundary is a standard stdio MCP server, not an API tied to one coding agent.

The first release must demonstrate the core loop described in the reverse-engineering article:

1. observe an application window;
2. return a bounded Accessibility tree and screenshot;
3. assign revision-scoped `element_index` values;
4. execute one action against the observed state;
5. invalidate the revision and require another observation.

## Non-goals

- Linux or Windows support
- AX tree diffing or cross-revision ID inheritance
- LockScreenGuardian or lock-screen automation
- Browser URL policy
- Telemetry
- Hidden password or secure-input access
- Compatibility with OpenAI's private `@oai/sky` protocol

## Repository layout

```text
blade-computer-use/
├── .claude-plugin/plugin.json
├── .codex-plugin/
│   ├── plugin.json
│   └── mcp.json
├── .mcp.json
├── native/BladeComputerUseHelper/
├── src/
│   ├── server.ts
│   ├── helper-client.ts
│   ├── policy.ts
│   └── tools/
├── skills/computer-use/SKILL.md
├── examples/orca-config.toml
├── scripts/build-native.sh
├── tests/
├── README.md
└── LICENSE
```

## Architecture

### Agent-neutral MCP server

The TypeScript process owns the public MCP contract. It uses the official Model Context Protocol SDK, validates tool arguments, enforces the app policy, launches the native helper, converts helper responses to MCP text/image content, and keeps helper diagnostics off stdout.

Codex, Claude Code, and Orca all start this same server over stdio:

```text
Codex plugin ───────┐
Claude Code plugin ─┼─> TypeScript MCP server ─> persistent Swift helper
Orca MCP config ────┘                              ├─ Accessibility
                                                  ├─ ScreenCaptureKit
                                                  └─ CGEvent
```

### Persistent Swift helper

The MCP server starts one Swift child process and communicates with newline-delimited JSON messages carrying request IDs. The helper keeps `AXUIElement` references in memory for the current revision, captures the selected window, and performs native input.

The helper uses:

- `NSWorkspace` and `CGWindowListCopyWindowInfo` for running apps and windows;
- `AXUIElement` for the Accessibility tree and element frames;
- `ScreenCaptureKit` for screenshots;
- `CGEvent` for clicks, Unicode text, key combinations, and scrolling.

The minimum supported system is macOS 14. The user must grant Accessibility and Screen Recording permissions to the terminal or coding-agent host that starts the server.

## MCP tools

### `list_apps`

Returns running GUI applications with display name, bundle identifier, process ID, and whether a capturable window is present. It never returns an AX tree or screenshot.

### `observe`

Input:

```json
{
  "app": "com.apple.TextEdit",
  "include_screenshot": true
}
```

Returns:

- canonical application identity;
- window title and bounds;
- a new opaque `revision` string;
- a bounded, line-oriented AX tree containing role, title/value summary, frame, and `element_index`;
- one PNG image content item when requested.

Traversal is depth-first, limited to 500 nodes and depth 12. Empty, hidden, and redundant layout-only nodes are omitted. Truncation is reported explicitly.

### `click`

Accepts one of:

- `element_index` plus the current `revision`;
- window-relative `x` and `y` plus the current `revision`.

The helper supports left/right buttons and one or two clicks. Element clicks use the center of the latest AX frame. Coordinate clicks first verify that the target window bounds still match the observation.

### `type_text`

Requires the current `revision` and injects Unicode text into the focused non-secure element using `CGEventKeyboardSetUnicodeString`. It does not read or replace the clipboard.

### `press_key`

Requires the current `revision` and supports common navigation keys, function keys, and Command/Control/Option/Shift modifiers through an explicit key map.

### `scroll`

Requires the current `revision`, accepts an optional element or coordinate target, and emits bounded pixel scrolling through `CGEvent`.

## Revision and element identity

Only one revision is current for an application. `observe` replaces the previous revision and rebuilds the `element_index -> AXUIElement` table. Every action consumes and invalidates that revision, whether the action succeeds or fails.

This deliberately omits diffing and ID inheritance. It gives all hosts the same simple rule: observe, perform one action, observe again. A stale or unknown revision returns `stale_revision` without generating input.

## Security and privacy

- `CUA_ALLOWED_APPS` is a comma-separated bundle-ID allowlist. Without it, only `list_apps` is available.
- `CUA_ALLOW_ALL_APPS=1` is an explicit escape hatch for local development.
- `loginwindow`, `SecurityAgent`, lock-screen processes, and AX secure text fields are always denied.
- The server does not make network requests or emit telemetry.
- Screenshots remain local until the selected MCP host includes the returned image in its own model request.
- Host-level confirmation remains the responsibility of Codex, Claude Code, or Orca; the server-side allowlist is enforced independently.

Errors use stable codes: `permission_denied`, `app_not_allowed`, `app_not_found`, `window_not_found`, `stale_revision`, `secure_input_denied`, `unsupported_key`, and `native_helper_error`.

## Host adapters

### Codex

`.codex-plugin/plugin.json` declares the skill and points to `.codex-plugin/mcp.json`. The MCP configuration launches the repository's wrapper script, which resolves its own installation path before starting `dist/server.js`.

### Claude Code

`.claude-plugin/plugin.json` declares plugin metadata. Root `.mcp.json` launches the same wrapper using `${CLAUDE_PLUGIN_ROOT}`. The root `skills/` directory contains the shared computer-use instructions.

### Orca

`examples/orca-config.toml` contains a `[[mcp_servers]]` stdio entry with command, arguments, environment allowlist, startup timeout, and tool timeout. Installation documentation explains that Orca loads MCP tools at session startup and exposes them under `mcp__blade_computer_use__*` names.

## Build and installation

`npm run build` compiles TypeScript and invokes `swift build -c release`. A wrapper under `bin/` locates the compiled helper and starts the MCP server without requiring global packages.

The README documents:

- prerequisites and macOS permissions;
- local build commands;
- Codex plugin installation;
- Claude Code `--plugin-dir` testing and plugin installation;
- Orca TOML configuration;
- a TextEdit smoke test;
- the security model and limitations.

## Testing

- TypeScript unit tests cover schemas, policy decisions, stable error mapping, and revision invalidation.
- MCP integration tests use a fixture helper to verify initialize, tools/list, text content, image content, and action errors without desktop permissions.
- Swift tests cover JSONL request decoding, bounded tree serialization, key mapping, coordinate validation, and secure-field rejection behind injectable protocols.
- A manual macOS smoke test observes TextEdit, clicks the editor, types text, scrolls, and verifies that reuse of the consumed revision fails.
- GitHub Actions runs TypeScript and Swift tests on macOS.

## Article integration

After the repository has a tested first release, the Chinese article adds a final `## 动手复刻：blade-computer-use` section linking to `https://github.com/echoVic/blade-computer-use`. It states that the project reproduces the public architecture and minimal observe/action loop, not OpenAI's private implementation or its full security model.
