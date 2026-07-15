import assert from 'node:assert/strict'
import { constants } from 'node:fs'
import { access, readFile, stat } from 'node:fs/promises'
import path from 'node:path'
import test from 'node:test'

const root = path.resolve(import.meta.dirname, '..')

async function json(relativePath: string): Promise<Record<string, unknown>> {
  return JSON.parse(await readFile(path.join(root, relativePath), 'utf8')) as Record<
    string,
    unknown
  >
}

test('Codex and Claude manifests launch the shared wrapper', async () => {
  const codex = await json('.codex-plugin/plugin.json')
  const sharedMcp = await json('.mcp.json')
  const claude = await json('.claude-plugin/plugin.json')

  assert.equal(codex.name, 'blade-computer-use')
  assert.equal(codex.version, '0.1.0')
  assert.equal(codex.mcpServers, './.mcp.json')
  assert.equal(codex.skills, './skills/')
  assert.equal(claude.name, 'blade-computer-use')
  assert.equal(claude.version, '0.1.0')

  const servers = sharedMcp.mcpServers as Record<
    string,
    { command: string; args: string[]; cwd?: string }
  >
  assert.equal(servers['blade-computer-use']?.command, 'sh')
  assert.equal(servers['blade-computer-use']?.cwd, '.')
  assert.match(
    servers['blade-computer-use']?.args.join(' ') ?? '',
    /\$\{CLAUDE_PLUGIN_ROOT:-\.\}\/bin\/blade-computer-use/,
  )
})

test('wrapper is executable and resolves the native helper and MCP server', async () => {
  const wrapperPath = path.join(root, 'bin/blade-computer-use')
  await access(wrapperPath, constants.X_OK)
  const mode = (await stat(wrapperPath)).mode
  assert.ok(mode & 0o111)

  const wrapper = await readFile(wrapperPath, 'utf8')
  assert.match(wrapper, /BLADE_COMPUTER_USE_HELPER/)
  assert.match(wrapper, /dist\/server\.js/)
})

test('shared skill and Orca example expose the same six tools', async () => {
  const skill = await readFile(path.join(root, 'skills/computer-use/SKILL.md'), 'utf8')
  const orca = await readFile(path.join(root, 'examples/orca-config.toml'), 'utf8')
  const names = ['list_apps', 'observe', 'click', 'type_text', 'press_key', 'scroll']

  for (const name of names) {
    assert.match(skill, new RegExp(`\\b${name}\\b`))
  }
  assert.match(skill, /observe after every action/i)
  assert.match(skill, /confirm/i)
  assert.match(orca, /\[\[mcp_servers\]\]/)
  assert.match(orca, /name = "blade-computer-use"/)
  assert.match(orca, /CUA_ALLOWED_APPS/)
})
