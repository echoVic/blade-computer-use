# blade-computer-use

`blade-computer-use` is a small, agent-neutral macOS computer-use implementation over the Model Context Protocol (MCP). It gives Codex, Claude Code, Orca, and other MCP clients the same six tools:

- `list_apps`
- `observe`
- `click`
- `type_text`
- `press_key`
- `scroll`

It is an independent security research project, not an OpenAI product and not a reproduction of OpenAI's private Computer Use implementation.

## How it works

```text
Coding agent
    | stdio MCP: schemas, allowlist, one-shot revisions, PNG responses
    v
TypeScript server (bundled as one runtime file)
    | JSONL request/response protocol
    v
Persistent Swift helper
    | AXUIElement          | ScreenCaptureKit       | CGEvent
    v                      v                        v
Accessibility tree     window screenshot      mouse/keyboard input
```

`observe` returns a bounded AX tree, a window screenshot, and an opaque revision. That revision permits exactly one action. The next action consumes it, so an agent must observe again before doing anything else. `element_index` values are scoped to that observation and are never treated as stable cross-frame identities.

## Requirements

- macOS 14 or newer
- Node.js 20 or newer
- Swift 5.10 or newer and the Xcode Command Line Tools (`xcode-select --install`)
- Accessibility and Screen Recording permission for the terminal or agent host running the plugin

The first plugin launch compiles the native helper for the current Mac. The TypeScript MCP server is already committed as a standalone bundle, so runtime installation does not run `npm install`.

## Codex

Install this repository as a Codex marketplace, then install the plugin:

```bash
codex plugin marketplace add echoVic/blade-computer-use
codex plugin add blade-computer-use@blade-computer-use
```

Restart the Codex app after installation. The packaged configuration allows only TextEdit by default.

For a custom allowlist, clone the repository, change `CUA_ALLOWED_APPS` in [`.mcp.json`](./.mcp.json), build once, and add the local checkout as the marketplace source:

```bash
git clone https://github.com/echoVic/blade-computer-use.git
cd blade-computer-use
npm install
npm run build
codex plugin marketplace add "$PWD"
codex plugin add blade-computer-use@blade-computer-use
```

Use comma-separated bundle identifiers, for example:

```json
"CUA_ALLOWED_APPS": "com.apple.TextEdit,com.apple.Notes"
```

`CUA_ALLOW_ALL_APPS=1` is available for local research, but the lock screen and SecurityAgent remain hard-denied.

## Claude Code

Clone the repository, then load it as a local Claude Code plugin:

```bash
git clone https://github.com/echoVic/blade-computer-use.git
claude --plugin-dir /absolute/path/to/blade-computer-use
```

Claude Code reads [`.claude-plugin/plugin.json`](./.claude-plugin/plugin.json) and the shared root [`.mcp.json`](./.mcp.json). `${CLAUDE_PLUGIN_ROOT}` is resolved by the launcher, so the checkout can live anywhere.

## Orca

Copy [the Orca MCP example](./examples/orca-config.toml) into Orca's configuration and replace the absolute command path. The example uses an underscore-safe server name, so Orca discovers the tools as `mcp__blade_computer_use__<tool>`.

## Permissions

Open **System Settings > Privacy & Security** and grant:

1. **Accessibility** to the terminal, Codex, Claude Code, or other host that starts the helper.
2. **Screen Recording** to the same host.

Restart the host after changing permissions. `list_apps` reports `accessibility_trusted`; `observe` returns a permission error instead of prompting or bypassing macOS controls.

## TextEdit smoke test

1. Open TextEdit and create a new plain-text document.
2. Ask the agent to call `list_apps` and find `com.apple.TextEdit`.
3. Ask it to `observe` TextEdit.
4. Ask it to click the editor, type a short line, and verify the result.

The expected loop is `observe -> one action -> observe`. A stale or already-consumed revision must not be retried.

## Security and privacy

- Apps require an explicit bundle-id allowlist; TextEdit is the only packaged default.
- `com.apple.loginwindow`, `com.apple.SecurityAgent`, and `com.apple.SecurityAgentHelper` are always denied.
- Secure AX fields reject `type_text`.
- Coordinate actions verify that the observed window has not moved or resized.
- Screenshots are written to a mode-`0700` temporary directory, read into the MCP image response, and deleted immediately afterward.
- No telemetry is implemented. AX text and screenshots are returned to the connected agent, whose own model-request and retention behavior is outside this project.

See [SECURITY.md](./SECURITY.md) for the trust boundary and reporting process.

## Current limits

This is deliberately smaller than a production computer-use stack:

- macOS-only; there is no Linux or Windows implementation.
- No AX diff protocol or cross-observation element identity matching.
- No lock-screen guardian, URL policy, or physical user-intervention detector.
- No OCR, browser-specific DOM bridge, or action-specific confirmation UI.
- No telemetry, account-policy integration, code signing, notarization, or prebuilt native binaries.
- The AX tree is capped at 500 nodes, depth 12, and 160 characters per text field.

## Development

```bash
npm install
npm test
npm run typecheck
npm run build
npm run validate:manifests
npm run smoke:mcp
```

The native checks use a framework-free self-test executable because a Command Line Tools-only Swift installation does not provide XCTest or the Swift Testing module:

```bash
npm run test:native
```

## License

MIT
