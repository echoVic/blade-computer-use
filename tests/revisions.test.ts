import assert from 'node:assert/strict'
import test from 'node:test'

import { RevisionStore } from '../src/revisions.js'

test('consumes each revision exactly once', () => {
  const revisions = new RevisionStore<{ title: string }>()
  revisions.replace('com.apple.TextEdit', 'revision-1', { title: 'Untitled' })

  assert.deepEqual(revisions.consume('com.apple.TextEdit', 'revision-1'), {
    title: 'Untitled',
  })
  assert.throws(
    () => revisions.consume('com.apple.TextEdit', 'revision-1'),
    { code: 'stale_revision' },
  )
})

test('a new observation invalidates the previous revision', () => {
  const revisions = new RevisionStore<number>()
  revisions.replace('com.apple.TextEdit', 'revision-1', 1)
  revisions.replace('com.apple.TextEdit', 'revision-2', 2)

  assert.throws(
    () => revisions.consume('com.apple.TextEdit', 'revision-1'),
    { code: 'stale_revision' },
  )
  assert.equal(revisions.consume('com.apple.TextEdit', 'revision-2'), 2)
})
