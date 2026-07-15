import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import path from 'node:path'
import test from 'node:test'

const root = path.resolve(import.meta.dirname, '..')

test('server closes the persistent helper when MCP stdin ends', async () => {
  const child = spawn(path.join(root, 'bin/blade-computer-use'), [], {
    cwd: root,
    env: { ...process.env, PATH: '/usr/bin:/bin:/usr/sbin:/sbin' },
    stdio: ['pipe', 'pipe', 'pipe'],
  })
  let stderr = ''
  child.stderr.setEncoding('utf8').on('data', (chunk) => {
    stderr += chunk
  })
  child.stdin.end()

  const exit = new Promise<{ code: number | null; signal: NodeJS.Signals | null }>(
    (resolve) => {
      child.once('exit', (code, signal) => resolve({ code, signal }))
    },
  )
  const timeout = new Promise<never>((_, reject) => {
    setTimeout(() => {
      child.kill('SIGTERM')
      reject(new Error(`server did not exit after stdin EOF: ${stderr}`))
    }, 4_000).unref()
  })

  const result = await Promise.race([exit, timeout])
  assert.deepEqual(result, { code: 0, signal: null })
})
