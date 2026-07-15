import { readFile, unlink } from 'node:fs/promises'

import type { CallToolResult } from '@modelcontextprotocol/sdk/types.js'

import { ComputerUseError } from './errors.js'
import type { ComputerUsePolicy } from './policy.js'
import { RevisionStore } from './revisions.js'
import { TOOL_SCHEMAS, type ToolName } from './schemas.js'

export interface HelperTransport {
  call(method: string, params: unknown): Promise<unknown>
}

export type ToolResponse = CallToolResult
type ToolContent = CallToolResult['content'][number]

export class ToolService {
  readonly #revisions = new RevisionStore<true>()

  constructor(
    private readonly helper: HelperTransport,
    private readonly policy: ComputerUsePolicy,
  ) {}

  async callTool(name: ToolName, input: unknown): Promise<ToolResponse> {
    const schema = TOOL_SCHEMAS[name]
    const args = schema.parse(input) as Record<string, unknown>

    if (name === 'list_apps') {
      return this.#text(await this.helper.call(name, args))
    }

    const app = this.#requiredString(args, 'app')
    this.policy.assertAllowed(app)

    if (name === 'observe') {
      const result = this.#object(await this.helper.call(name, args))
      const observedApp = this.#requiredString(result, 'app')
      const revision = this.#requiredString(result, 'revision')
      this.#revisions.replace(observedApp, revision, true)
      return this.#observationContent(result)
    }

    const revision = this.#requiredString(args, 'revision')
    this.#revisions.consume(app, revision)
    return this.#text(await this.helper.call(name, args))
  }

  async #observationContent(result: Record<string, unknown>): Promise<ToolResponse> {
    const screenshotPath =
      typeof result.screenshot_path === 'string' ? result.screenshot_path : undefined
    const publicResult = { ...result }
    delete publicResult.screenshot_path
    const content: ToolContent[] = [
      { type: 'text', text: JSON.stringify(publicResult, null, 2) },
    ]

    if (screenshotPath) {
      try {
        const data = await readFile(screenshotPath)
        content.push({
          type: 'image',
          data: data.toString('base64'),
          mimeType: 'image/png',
        })
      } finally {
        await unlink(screenshotPath).catch(() => undefined)
      }
    }
    return { content }
  }

  #text(result: unknown): ToolResponse {
    return { content: [{ type: 'text', text: JSON.stringify(result, null, 2) }] }
  }

  #object(value: unknown): Record<string, unknown> {
    if (!value || typeof value !== 'object' || Array.isArray(value)) {
      throw new ComputerUseError(
        'native_helper_error',
        'Native helper returned a non-object result.',
      )
    }
    return value as Record<string, unknown>
  }

  #requiredString(object: Record<string, unknown>, key: string): string {
    const value = object[key]
    if (typeof value !== 'string' || value.length === 0) {
      throw new ComputerUseError(
        'native_helper_error',
        `Expected string field ${key} from the native helper.`,
      )
    }
    return value
  }
}
