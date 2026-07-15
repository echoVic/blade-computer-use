# Security Policy

## Reporting a security vulnerability

Please use GitHub's private vulnerability reporting for this repository. Do not open a public issue with exploit details, screenshots, captured interface text, credentials, or other sensitive data.

Include the affected commit, macOS version, agent host, minimum reproduction, expected boundary, and observed behavior. You should receive an initial response within seven days.

## Trust boundary

The TypeScript MCP process enforces the application allowlist and consumes each observation revision once. The Swift helper independently binds actions to its current in-memory revision and AX references. Both checks are intentional: a caller must not bypass the Node policy by speaking directly to stale helper state.

The native helper can read accessibility text, capture an allowed window, and synthesize input after macOS permissions are granted. Treat the agent host, plugin files, environment, and local user account as trusted. The project does not isolate a malicious local process with the same user privileges.

## Known limitations

- Bundle identifiers are the application policy boundary; there is no per-window or URL policy.
- Element indices are valid only for one observation and do not provide stable identity across revisions.
- The project does not detect physical user input or guard the lock-screen lifecycle.
- Screenshots and AX text are sent to the connected MCP client. No telemetry is added by this project, but the client may send that context to its configured model provider.
- The native helper is built locally and is not code-signed or notarized.

The hard-denied lock-screen and SecurityAgent bundle identifiers and secure-field typing check are defense-in-depth controls, not a complete desktop sandbox.
