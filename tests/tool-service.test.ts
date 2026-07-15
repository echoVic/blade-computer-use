import assert from 'node:assert/strict'
import { mkdtemp, readFile, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import path from 'node:path'
import test from 'node:test'

import { createPolicy } from '../src/policy.js'
import { ToolService, type HelperTransport } from '../src/tool-service.js'

class FakeHelper implements HelperTransport {
  readonly calls: Array<{ method: string; params: unknown }> = []
  readonly responses: unknown[] = []

  async call(method: string, params: unknown): Promise<unknown> {
    this.calls.push({ method, params })
    return this.responses.shift()
  }
}

test('blocks unapproved apps before calling the helper', async () => {
  const helper = new FakeHelper()
  const service = new ToolService(helper, createPolicy({}))

  await assert.rejects(
    () => service.callTool('observe', { app: 'com.apple.TextEdit' }),
    { code: 'app_not_allowed' },
  )
  assert.equal(helper.calls.length, 0)
})

test('returns screenshot image content and removes the temporary PNG', async () => {
  const helper = new FakeHelper()
  const directory = await mkdtemp(path.join(tmpdir(), 'blade-cu-test-'))
  const screenshot = path.join(directory, 'window.png')
  await writeFile(screenshot, Buffer.from([0x89, 0x50, 0x4e, 0x47]))
  helper.responses.push({
    app: 'com.apple.TextEdit',
    revision: 'revision-1',
    ax_tree: '[0] AXWindow',
    screenshot_path: screenshot,
  })
  const service = new ToolService(
    helper,
    createPolicy({ CUA_ALLOWED_APPS: 'com.apple.TextEdit' }),
  )

  const response = await service.callTool('observe', {
    app: 'com.apple.TextEdit',
    include_screenshot: true,
  })

  assert.equal(response.content[0]?.type, 'text')
  assert.deepEqual(response.content[1], {
    type: 'image',
    data: 'iVBORw==',
    mimeType: 'image/png',
  })
  await assert.rejects(() => readFile(screenshot), { code: 'ENOENT' })
})

test('consumes an observed revision before the action helper call', async () => {
  const helper = new FakeHelper()
  helper.responses.push(
    {
      app: 'com.apple.TextEdit',
      revision: 'revision-1',
      ax_tree: '[0] AXWindow',
    },
    { ok: true, revision_consumed: 'revision-1' },
  )
  const service = new ToolService(
    helper,
    createPolicy({ CUA_ALLOWED_APPS: 'com.apple.TextEdit' }),
  )
  await service.callTool('observe', { app: 'com.apple.TextEdit' })

  await service.callTool('click', {
    app: 'com.apple.TextEdit',
    revision: 'revision-1',
    element_index: 0,
  })
  await assert.rejects(
    () =>
      service.callTool('click', {
        app: 'com.apple.TextEdit',
        revision: 'revision-1',
        element_index: 0,
      }),
    { code: 'stale_revision' },
  )
  assert.equal(helper.calls.length, 2)
})
