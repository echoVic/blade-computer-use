#!/usr/bin/env node

import path from 'node:path'
import { fileURLToPath } from 'node:url'

import { Server } from '@modelcontextprotocol/sdk/server/index.js'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js'

import { toErrorPayload } from './errors.js'
import { NativeHelperClient } from './helper-client.js'
import { createPolicy } from './policy.js'
import { TOOL_DEFINITIONS, type ToolName } from './schemas.js'
import { ToolService } from './tool-service.js'

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const helperPath =
  process.env.BLADE_COMPUTER_USE_HELPER ??
  path.join(
    repositoryRoot,
    'native/BladeComputerUseHelper/.build/release/BladeComputerUseHelper',
  )
const helper = new NativeHelperClient(helperPath)
const service = new ToolService(helper, createPolicy())
const server = new Server(
  { name: 'blade-computer-use', version: '0.1.0' },
  { capabilities: { tools: {} } },
)

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: TOOL_DEFINITIONS.map((tool) => ({ ...tool })),
}))

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const name = request.params.name as ToolName
  if (!TOOL_DEFINITIONS.some((tool) => tool.name === name)) {
    return {
      isError: true,
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            code: 'invalid_request',
            message: `Unknown tool: ${request.params.name}`,
          }),
        },
      ],
    }
  }

  try {
    return await service.callTool(name, request.params.arguments ?? {})
  } catch (error) {
    return {
      isError: true,
      content: [{ type: 'text', text: JSON.stringify(toErrorPayload(error)) }],
    }
  }
})

const transport = new StdioServerTransport()
await server.connect(transport)

async function shutdown(): Promise<void> {
  await helper.close()
  await server.close()
}

process.once('SIGINT', () => void shutdown())
process.once('SIGTERM', () => void shutdown())
