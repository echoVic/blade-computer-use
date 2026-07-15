---
name: computer-use
description: Use when a user asks to inspect, navigate, or operate an explicitly allowed macOS application through the blade-computer-use MCP tools.
---

# Computer Use

Operate one allowed macOS app at a time. Treat every observation revision as a single-use capability for exactly one action.

## Workflow

1. Call `list_apps` and identify the target bundle identifier.
2. Call `observe` for that app. Use `element_index` when a suitable AX node exists; use window-relative coordinates only as a fallback.
3. Confirm immediately before impactful actions such as sending, submitting, purchasing, deleting, publishing, or changing permissions.
4. Perform one `click`, `type_text`, `press_key`, or `scroll` with the revision returned by that observation.
5. Observe after every action. Never reuse a revision or assume the interface remained unchanged.

If an action reports a stale or consumed revision, observe again and reassess the current interface. Do not replay the old action blindly.

## Tools

| Tool | Purpose |
| --- | --- |
| `list_apps` | List running GUI apps and bundle identifiers. |
| `observe` | Return the current AX tree, revision, and optional screenshot. |
| `click` | Click an AX element or window-relative coordinate. |
| `type_text` | Type Unicode text into the focused non-secure field. |
| `press_key` | Press a supported key with optional modifiers. |
| `scroll` | Scroll at an element, coordinate, or window center. |

## Safety

- Stay within the app the user named and the configured `CUA_ALLOWED_APPS` policy.
- Explain when Accessibility or Screen Recording permission is missing; do not weaken the policy to bypass it.
- Never target `loginwindow`, `SecurityAgent`, password fields, or other secure input surfaces.
- Pause when the visible state differs from the user's request or when physical user input changes the target.
- Prefer a purpose-built API or CLI when it can complete the task with less UI access.

## Common Mistakes

- Reusing a revision: observe again before retrying.
- Guessing screen coordinates from an old screenshot: use the current AX element index first.
- Chaining several actions from one observation: one observation permits one action only.
- Treating a successful input event as task completion: verify the resulting state with `observe`.
