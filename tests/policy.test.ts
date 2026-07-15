import assert from 'node:assert/strict'
import test from 'node:test'

import { createPolicy } from '../src/policy.js'

test('requires an explicit allowlist for observation', () => {
  const policy = createPolicy({})

  assert.throws(() => policy.assertAllowed('com.apple.TextEdit'), {
    code: 'app_not_allowed',
  })
})

test('parses a comma-separated bundle ID allowlist', () => {
  const policy = createPolicy({
    CUA_ALLOWED_APPS: ' com.apple.TextEdit,com.apple.Safari ',
  })

  assert.doesNotThrow(() => policy.assertAllowed('com.apple.TextEdit'))
  assert.throws(() => policy.assertAllowed('com.apple.Notes'), {
    code: 'app_not_allowed',
  })
})

test('hard-denied apps stay denied when allow-all is enabled', () => {
  const policy = createPolicy({ CUA_ALLOW_ALL_APPS: '1' })

  assert.throws(() => policy.assertAllowed('com.apple.loginwindow'), {
    code: 'app_not_allowed',
  })
  assert.doesNotThrow(() => policy.assertAllowed('com.apple.TextEdit'))
})
