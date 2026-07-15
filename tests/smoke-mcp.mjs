import assert from 'node:assert/strict'
import path from 'node:path'

import { Client } from '@modelcontextprotocol/sdk/client/index.js'
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js'

const root = path.resolve(import.meta.dirname, '..')
const command = process.env.BLADE_MCP_COMMAND ?? path.join(root, 'bin/blade-computer-use')
const transport = new StdioClientTransport({
  command,
  cwd: root,
  stderr: 'pipe',
})
const client = new Client({ name: 'blade-computer-use-smoke', version: '0.1.0' })

try {
  await client.connect(transport)
  const result = await client.listTools()
  assert.deepEqual(
    result.tools.map((tool) => tool.name),
    ['list_apps', 'observe', 'click', 'type_text', 'press_key', 'scroll'],
  )
  process.stdout.write('MCP smoke test passed: six tools available.\n')
} finally {
  await client.close()
}
