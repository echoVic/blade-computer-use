import assert from 'node:assert/strict'
import test from 'node:test'

import { TOOL_DEFINITIONS } from '../src/schemas.js'

test('publishes exactly the six cross-agent computer-use tools', () => {
  assert.deepEqual(
    TOOL_DEFINITIONS.map((tool) => tool.name),
    ['list_apps', 'observe', 'click', 'type_text', 'press_key', 'scroll'],
  )
})
