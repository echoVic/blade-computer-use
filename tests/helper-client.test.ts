import assert from 'node:assert/strict'
import { fileURLToPath } from 'node:url'
import test from 'node:test'

import { NativeHelperClient } from '../src/helper-client.js'

const fixturePath = fileURLToPath(
  new URL('./fixtures/helper.mjs', import.meta.url),
)

test('matches JSONL helper responses by request ID', async () => {
  const client = new NativeHelperClient(process.execPath, [fixturePath])

  try {
    const [first, second] = await Promise.all([
      client.call('list_apps', {}),
      client.call('observe', { app: 'com.apple.TextEdit' }),
    ])

    assert.deepEqual(first, { method: 'list_apps', params: {} })
    assert.deepEqual(second, {
      method: 'observe',
      params: { app: 'com.apple.TextEdit' },
    })
  } finally {
    await client.close()
  }
})
