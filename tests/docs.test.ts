import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import path from 'node:path'
import test from 'node:test'

const root = path.resolve(import.meta.dirname, '..')
const read = (relativePath: string) => readFile(path.join(root, relativePath), 'utf8')

test('public docs cover installation, permissions, policy, and limits', async () => {
  const readme = await read('README.md')
  const security = await read('SECURITY.md')
  const license = await read('LICENSE')

  for (const term of [
    'Codex',
    'Claude Code',
    'Orca',
    'Accessibility',
    'Screen Recording',
    'CUA_ALLOWED_APPS',
    'TextEdit',
    'macOS-only',
    'No telemetry',
  ]) {
    assert.match(readme, new RegExp(term, 'i'))
  }
  assert.match(readme, /not an OpenAI product/i)
  assert.match(security, /security vulnerability/i)
  assert.match(security, /revision/i)
  assert.match(license, /MIT License/)
})

test('macOS CI runs Node checks and the native self-test', async () => {
  const ci = await read('.github/workflows/ci.yml')
  assert.match(ci, /runs-on: macos-14/)
  assert.match(ci, /npm ci/)
  assert.match(ci, /npm test/)
  assert.match(ci, /npm run typecheck/)
  assert.match(ci, /npm run test:native/)
  assert.match(ci, /npm run validate:manifests/)
  assert.doesNotMatch(ci, /swift test/)
})
