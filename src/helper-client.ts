import { spawn, type ChildProcessWithoutNullStreams } from 'node:child_process'
import readline from 'node:readline'

import {
  ComputerUseError,
  type ComputerUseErrorCode,
} from './errors.js'

interface HelperResponse {
  id: string
  result?: unknown
  error?: {
    code: ComputerUseErrorCode
    message: string
    details?: unknown
  }
}

interface PendingCall {
  resolve(value: unknown): void
  reject(reason: unknown): void
}

export class NativeHelperClient {
  readonly #child: ChildProcessWithoutNullStreams
  readonly #pending = new Map<string, PendingCall>()
  #nextId = 1

  constructor(command: string, args: readonly string[] = []) {
    this.#child = spawn(command, [...args], {
      stdio: ['pipe', 'pipe', 'pipe'],
    })
    this.#child.stderr.pipe(process.stderr)

    const lines = readline.createInterface({ input: this.#child.stdout })
    lines.on('line', (line) => this.#handleLine(line))
    this.#child.once('error', (error) => this.#rejectAll(error))
    this.#child.once('exit', (code, signal) => {
      this.#rejectAll(
        new ComputerUseError(
          'native_helper_error',
          `Native helper exited (${signal ?? code ?? 'unknown'}).`,
        ),
      )
    })
  }

  call(method: string, params: unknown): Promise<unknown> {
    const id = String(this.#nextId++)
    return new Promise((resolve, reject) => {
      this.#pending.set(id, { resolve, reject })
      this.#child.stdin.write(`${JSON.stringify({ id, method, params })}\n`)
    })
  }

  async close(): Promise<void> {
    if (this.#child.exitCode !== null || this.#child.signalCode !== null) return

    const exited = new Promise<void>((resolve) => {
      this.#child.once('exit', () => resolve())
    })
    this.#child.stdin.end()
    await exited
  }

  #handleLine(line: string): void {
    let response: HelperResponse
    try {
      response = JSON.parse(line) as HelperResponse
    } catch (error) {
      this.#rejectAll(
        new ComputerUseError(
          'native_helper_error',
          `Native helper returned invalid JSON: ${String(error)}`,
        ),
      )
      return
    }

    const pending = this.#pending.get(response.id)
    if (!pending) return
    this.#pending.delete(response.id)

    if (response.error) {
      pending.reject(
        new ComputerUseError(
          response.error.code,
          response.error.message,
          response.error.details,
        ),
      )
      return
    }
    pending.resolve(response.result)
  }

  #rejectAll(error: unknown): void {
    for (const pending of this.#pending.values()) pending.reject(error)
    this.#pending.clear()
  }
}
