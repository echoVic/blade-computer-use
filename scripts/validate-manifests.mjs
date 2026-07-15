import assert from 'node:assert/strict'
import { constants } from 'node:fs'
import { access, readFile } from 'node:fs/promises'
import path from 'node:path'

const root = path.resolve(import.meta.dirname, '..')
const readJson = async (relativePath) =>
  JSON.parse(await readFile(path.join(root, relativePath), 'utf8'))

const codex = await readJson('.codex-plugin/plugin.json')
const sharedMcp = await readJson('.mcp.json')
const claude = await readJson('.claude-plugin/plugin.json')

assert.equal(codex.name, 'blade-computer-use')
assert.equal(codex.version, '0.1.0')
assert.equal(codex.skills, './skills/')
assert.equal(codex.mcpServers, './.mcp.json')
assert.equal(claude.name, codex.name)
assert.equal(claude.version, codex.version)
assert.equal(
  sharedMcp.mcpServers['blade-computer-use'].command,
  'sh',
)
assert.match(
  sharedMcp.mcpServers['blade-computer-use'].args.join(' '),
  /\$\{CLAUDE_PLUGIN_ROOT:-\.\}\/bin\/blade-computer-use/,
)

await access(path.join(root, 'bin/blade-computer-use'), constants.X_OK)
await access(path.join(root, 'skills/computer-use/SKILL.md'), constants.R_OK)
process.stdout.write('Plugin manifests are valid.\n')
