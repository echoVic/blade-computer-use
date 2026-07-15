export type ComputerUseErrorCode =
  | 'permission_denied'
  | 'app_not_allowed'
  | 'app_not_found'
  | 'window_not_found'
  | 'stale_revision'
  | 'secure_input_denied'
  | 'unsupported_key'
  | 'native_helper_error'
  | 'invalid_request'

export class ComputerUseError extends Error {
  constructor(
    public readonly code: ComputerUseErrorCode,
    message: string,
    public readonly details?: unknown,
  ) {
    super(message)
    this.name = 'ComputerUseError'
  }
}

export function toErrorPayload(error: unknown): {
  code: ComputerUseErrorCode
  message: string
  details?: unknown
} {
  if (error instanceof ComputerUseError) {
    return {
      code: error.code,
      message: error.message,
      ...(error.details === undefined ? {} : { details: error.details }),
    }
  }

  return {
    code: 'native_helper_error',
    message: error instanceof Error ? error.message : String(error),
  }
}
