import assert from 'node:assert/strict'
import path from 'node:path'

import { Client } from '@modelcontextprotocol/sdk/client/index.js'
import {
  getDefaultEnvironment,
  StdioClientTransport,
} from '@modelcontextprotocol/sdk/client/stdio.js'

const root = path.resolve(import.meta.dirname, '..')
const testText =
  process.env.BLADE_TEXTEDIT_TEST_TEXT ??
  `blade-computer-use 中文 live test ${new Date().toISOString()}`
const rejectedText = 'REUSED_REVISION_MUST_NOT_APPEAR'
const transport = new StdioClientTransport({
  command: path.join(root, 'bin/blade-computer-use'),
  cwd: root,
  env: {
    ...getDefaultEnvironment(),
    CUA_ALLOWED_APPS: 'com.apple.TextEdit',
  },
  stderr: 'pipe',
})
transport.stderr?.on('data', (chunk) => process.stderr.write(chunk))
const client = new Client({ name: 'blade-textedit-live-test', version: '0.1.0' })

function textPayload(result) {
  const text = result.content.find((content) => content.type === 'text')?.text
  assert.ok(text, 'tool result must include text content')
  return JSON.parse(text)
}

try {
  await client.connect(transport)

  const appsResult = await client.callTool({ name: 'list_apps', arguments: {} })
  const apps = textPayload(appsResult)
  assert.equal(apps.accessibility_trusted, true)
  assert.equal(apps.screen_recording_trusted, true)
  assert.ok(apps.apps.some((app) => app.bundle_id === 'com.apple.TextEdit'))

  const beforeResult = await client.callTool({
    name: 'observe',
    arguments: { app: 'com.apple.TextEdit', include_screenshot: true },
  })
  assert.equal(beforeResult.isError, undefined)
  assert.ok(beforeResult.content.some((content) => content.type === 'image'))
  const before = textPayload(beforeResult)

  const typeResult = await client.callTool({
    name: 'type_text',
    arguments: {
      app: 'com.apple.TextEdit',
      revision: before.revision,
      text: testText,
    },
  })
  assert.equal(
    typeResult.isError,
    undefined,
    `type_text failed: ${JSON.stringify(typeResult.content)}`,
  )

  const reusedResult = await client.callTool({
    name: 'type_text',
    arguments: {
      app: 'com.apple.TextEdit',
      revision: before.revision,
      text: rejectedText,
    },
  })
  assert.equal(reusedResult.isError, true)

  const afterResult = await client.callTool({
    name: 'observe',
    arguments: { app: 'com.apple.TextEdit', include_screenshot: true },
  })
  assert.ok(afterResult.content.some((content) => content.type === 'image'))
  const after = textPayload(afterResult)
  assert.match(
    after.ax_tree,
    new RegExp(testText.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i'),
  )
  assert.doesNotMatch(after.ax_tree, new RegExp(rejectedText))

  process.stdout.write(
    `TextEdit live test passed: observe -> type_text -> stale revision rejection -> observe (${testText})\n`,
  )
} finally {
  await client.close()
}
