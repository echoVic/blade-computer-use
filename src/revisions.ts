import { ComputerUseError } from './errors.js'

interface RevisionEntry<T> {
  revision: string
  value: T
}

export class RevisionStore<T> {
  readonly #entries = new Map<string, RevisionEntry<T>>()

  replace(app: string, revision: string, value: T): void {
    this.#entries.set(app, { revision, value })
  }

  consume(app: string, revision: string): T {
    const current = this.#entries.get(app)
    if (!current || current.revision !== revision) {
      throw new ComputerUseError(
        'stale_revision',
        `Revision ${revision} is no longer current for ${app}. Observe again.`,
      )
    }

    this.#entries.delete(app)
    return current.value
  }

  clear(app: string): void {
    this.#entries.delete(app)
  }
}
