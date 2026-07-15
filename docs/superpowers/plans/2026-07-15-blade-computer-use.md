# Blade Computer Use Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and publish a macOS-only computer-use MCP server that exposes the same observe-one-action-observe loop to Codex, Claude Code, and Orca.

**Architecture:** A TypeScript stdio MCP server owns schemas, policy, revision consumption, and MCP image responses. It keeps one Swift helper alive over JSONL; the helper owns AX references, ScreenCaptureKit capture, and CGEvent input. Codex and Claude Code use separate plugin manifests while Orca receives a native `[[mcp_servers]]` example.

**Tech Stack:** TypeScript 7, Node.js 24, `@modelcontextprotocol/sdk` 1.29, Zod 4, Node test runner through `tsx`, Swift 6.2, Swift Package Manager, Accessibility, AppKit, ScreenCaptureKit, CGEvent

---

### Task 1: Scaffold the TypeScript core with policy and revision tests

**Files:**

- Create: `package.json`
- Create: `tsconfig.json`
- Create: `.gitignore`
- Create: `src/errors.ts`
- Create: `src/policy.ts`
- Create: `src/revisions.ts`
- Test: `tests/policy.test.ts`
- Test: `tests/revisions.test.ts`

- [ ] **Step 1: Write policy tests that fail before the module exists**

```ts
test('requires an explicit allowlist for observation', () => {
  const policy = createPolicy({})
  assert.throws(() => policy.assertAllowed('com.apple.TextEdit'), {
    code: 'app_not_allowed',
  })
})

test('hard-denied apps stay denied when allow-all is enabled', () => {
  const policy = createPolicy({ CUA_ALLOW_ALL_APPS: '1' })
  assert.throws(() => policy.assertAllowed('com.apple.loginwindow'), {
    code: 'app_not_allowed',
  })
})
```

- [ ] **Step 2: Run the focused tests and observe module-not-found failures**

Run: `npm test -- tests/policy.test.ts tests/revisions.test.ts`

Expected: FAIL because `src/policy.ts` and `src/revisions.ts` do not exist.

- [ ] **Step 3: Implement `ComputerUseError`, `createPolicy`, and `RevisionStore`**

`createPolicy` parses `CUA_ALLOWED_APPS` as comma-separated bundle IDs, trims whitespace, uses exact matching, honors `CUA_ALLOW_ALL_APPS=1`, and applies the hard denylist last. `RevisionStore.consume(app, revision)` must delete the current entry before returning it. A second consume returns `stale_revision`.

- [ ] **Step 4: Run tests and type checking**

Run: `npm test && npm run typecheck`

Expected: all policy/revision tests pass and TypeScript reports zero errors.

- [ ] **Step 5: Commit the tested core**

```bash
git add package.json package-lock.json tsconfig.json .gitignore src tests
git commit -m "feat: add policy and revision core"
```

### Task 2: Build the persistent helper protocol

**Files:**

- Create: `src/helper-client.ts`
- Create: `tests/fixtures/helper.mjs`
- Test: `tests/helper-client.test.ts`
- Create: `native/BladeComputerUseHelper/Package.swift`
- Create: `native/BladeComputerUseHelper/Sources/BladeComputerUseCore/Protocol.swift`
- Create: `native/BladeComputerUseHelper/Sources/BladeComputerUseHelper/main.swift`
- Test: `native/BladeComputerUseHelper/Sources/BladeComputerUseHelperSelfTest/main.swift`

- [ ] **Step 1: Write a failing Node helper-client test**

The fixture reads one JSON line and replies with the same request ID. The test sends `{ method: 'list_apps', params: {} }` and expects the response payload.

- [ ] **Step 2: Run the helper-client test and observe the missing client failure**

Run: `npm test -- tests/helper-client.test.ts`

Expected: FAIL because `NativeHelperClient` is not implemented.

- [ ] **Step 3: Implement the JSONL client**

Use `spawn`, `readline.createInterface`, monotonically increasing string IDs, a pending promise map, stderr forwarding, and rejection of all pending calls when the helper exits.

- [ ] **Step 4: Write Swift self-tests before the protocol types**

```swift
let request = HelperRequest(id: "1", method: "list_apps", params: [:])
let data = try JSONEncoder().encode(request)
check(try JSONDecoder().decode(HelperRequest.self, from: data) == request)
```

- [ ] **Step 5: Implement Codable request/response envelopes and the stdin loop**

The executable reads stdin lines, decodes one request, calls a temporary dispatcher, and writes exactly one compact JSON response to stdout. Diagnostics go to stderr.

- [ ] **Step 6: Verify Node and Swift protocol tests**

Run:

```bash
npm test -- tests/helper-client.test.ts
npm run test:native
```

Expected: both suites pass.

- [ ] **Step 7: Commit the protocol boundary**

```bash
git add src/helper-client.ts tests native
git commit -m "feat: add native helper protocol"
```

### Task 3: Implement macOS observation and actions in Swift

**Files:**

- Create: `native/BladeComputerUseHelper/Sources/BladeComputerUseCore/AXTree.swift`
- Create: `native/BladeComputerUseHelper/Sources/BladeComputerUseCore/Models.swift`
- Create: `native/BladeComputerUseHelper/Sources/BladeComputerUseCore/NativeService.swift`
- Create: `native/BladeComputerUseHelper/Sources/BladeComputerUseCore/ScreenCapture.swift`
- Create: `native/BladeComputerUseHelper/Sources/BladeComputerUseCore/Input.swift`
- Modify: `native/BladeComputerUseHelper/Sources/BladeComputerUseHelper/main.swift`
- Test: `native/BladeComputerUseHelper/Sources/BladeComputerUseHelperSelfTest/main.swift`

- [ ] **Step 1: Write failing pure tests for tree limits and key mapping**

Use a synthetic `AXNodeSource` tree to prove depth 12, node count 500, deterministic element indices, explicit truncation, secure-role detection, and mappings for Return, Escape, Tab, arrows, and Command/Control/Option/Shift.

- [ ] **Step 2: Run Swift tests and observe missing native modules**

Run: `npm run test:native`

Expected: FAIL because serializer and key mapper types are absent.

- [ ] **Step 3: Implement the bounded AX serializer and input helpers**

The serializer stores live `AXUIElement` references by index in the current snapshot. Input helpers reject secure fields and use CGEvent for click, Unicode typing, keys, and pixel scroll.

- [ ] **Step 4: Implement app/window discovery and ScreenCaptureKit PNG capture**

Use bundle IDs as canonical app IDs, prefer the focused AX window, capture the matching on-screen window, and write PNGs under a private temporary directory. Return the file path to Node.

- [ ] **Step 5: Implement revision consumption in `NativeService`**

`observe` replaces the app snapshot. Every action removes the snapshot before validating the element/coordinates and returns `stale_revision` on reuse.

- [ ] **Step 6: Wire every helper method through the dispatcher**

Methods are `list_apps`, `observe`, `click`, `type_text`, `press_key`, and `scroll`. Errors preserve the stable design codes.

- [ ] **Step 7: Run Swift tests and build the release helper**

Run:

```bash
npm run test:native
swift build --package-path native/BladeComputerUseHelper -c release
```

Expected: tests and release build pass with Command Line Tools only.

- [ ] **Step 8: Commit native computer use**

```bash
git add native
git commit -m "feat: add macOS observation and input"
```

### Task 4: Expose the MCP tool surface

**Files:**

- Create: `src/schemas.ts`
- Create: `src/server.ts`
- Create: `src/tool-service.ts`
- Test: `tests/tool-service.test.ts`
- Test: `tests/mcp-server.test.ts`

- [ ] **Step 1: Write failing tool-service tests**

Cover allowlist enforcement, text observation content, PNG image content, stale revision errors, and cleanup of the temporary screenshot after reading.

- [ ] **Step 2: Run focused tests and observe missing service failures**

Run: `npm test -- tests/tool-service.test.ts tests/mcp-server.test.ts`

Expected: FAIL because schemas, tool service, and MCP handlers are absent.

- [ ] **Step 3: Implement Zod schemas and `ToolService`**

All app tools call policy before the helper. `observe` returns JSON text plus optional `{ type: 'image', data, mimeType: 'image/png' }`. Action tools return structured JSON text and consume the helper revision.

- [ ] **Step 4: Implement the stdio MCP server with the official SDK**

Register exactly six tools and connect `StdioServerTransport`. Never write logs to stdout.

- [ ] **Step 5: Run Node tests, typecheck, and a tools/list smoke test**

Run:

```bash
npm test
npm run typecheck
npm run build
node tests/smoke-mcp.mjs
```

Expected: all tests pass and the smoke client discovers six tools.

- [ ] **Step 6: Commit the MCP server**

```bash
git add src tests package.json package-lock.json tsconfig.json
git commit -m "feat: expose computer use over mcp"
```

### Task 5: Add Codex, Claude Code, and Orca installation surfaces

**Files:**

- Create: `.codex-plugin/plugin.json`
- Create: `.agents/plugins/marketplace.json`
- Create: `.claude-plugin/plugin.json`
- Create: `.mcp.json`
- Create: `skills/computer-use/SKILL.md`
- Create: `examples/orca-config.toml`
- Create: `bin/blade-computer-use`
- Create: `scripts/build-native.sh`
- Create: `scripts/validate-manifests.mjs`
- Test: `tests/manifests.test.ts`

- [ ] **Step 1: Write failing manifest and wrapper tests**

Validate JSON syntax, names/versions, the repository marketplace entry, executable wrapper mode, shared root MCP config, Claude `${CLAUDE_PLUGIN_ROOT}` fallback, and the six tool names in the shared skill.

- [ ] **Step 2: Run the manifest tests and observe missing-file failures**

Run: `npm test -- tests/manifests.test.ts`

Expected: FAIL listing the missing plugin files.

- [ ] **Step 3: Create both plugin manifests, MCP configs, wrapper, skill, and Orca example**

The wrapper resolves the repository root, builds the Swift helper on first use, and executes the committed `dist/blade-computer-use.mjs` bundle. The skill requires observe after every action and warns about impactful actions.

- [ ] **Step 4: Validate manifests and start the built server through the wrapper**

Run:

```bash
npm run validate:manifests
./bin/blade-computer-use </dev/null
```

Expected: manifests pass; the server initializes without writing non-MCP text to stdout and exits when stdin closes.

- [ ] **Step 5: Commit host adapters**

```bash
git add .codex-plugin .claude-plugin .mcp.json skills examples bin scripts tests
git commit -m "feat: add coding agent adapters"
```

### Task 6: Document, release, and link the article

**Files:**

- Create: `README.md`
- Create: `LICENSE`
- Create: `SECURITY.md`
- Create: `.github/workflows/ci.yml`
- Modify: `package.json`
- Modify: `/Users/bytedance/Documents/GitHub/qingyun-blog/src/content/blog/AI/chatgpt-computer-use-plugin-security-analysis.mdx`

- [ ] **Step 1: Write the public documentation**

Document requirements, permissions, build, the three install paths, allowlist examples, TextEdit smoke test, architecture, security, privacy, and explicit non-goals. Use `blade-computer-use` consistently.

- [ ] **Step 2: Add macOS CI**

CI installs Node dependencies, runs Node tests/typecheck/build, and runs the framework-free Swift self-test plus release build on `macos-14`.

- [ ] **Step 3: Run the complete verification suite**

Run:

```bash
npm ci
npm test
npm run typecheck
npm run build
npm run validate:manifests
npm run test:native
git diff --check
```

Expected: every command exits zero.

- [ ] **Step 4: Commit and push the repository**

```bash
git add README.md LICENSE SECURITY.md .github package.json package-lock.json docs
git commit -m "docs: publish blade computer use"
git push origin main
```

- [ ] **Step 5: Add the project to the article**

Append `## 动手复刻：blade-computer-use` after the version note. Link to `https://github.com/echoVic/blade-computer-use`, describe the six-tool macOS MVP, and state that it does not reproduce OpenAI's private implementation or full security model.

- [ ] **Step 6: Verify and push the blog update**

Run the qingyun-blog formatter, typecheck, build, and local preview checks while preserving pre-existing staged `.astro` changes. Do not push qingyun-blog unless the user explicitly asks for that repository to be pushed.
