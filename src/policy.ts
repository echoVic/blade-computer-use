import { ComputerUseError } from './errors.js'

const HARD_DENIED_BUNDLE_IDS = new Set([
  'com.apple.loginwindow',
  'com.apple.SecurityAgent',
  'com.apple.SecurityAgentHelper',
])

export interface ComputerUsePolicy {
  assertAllowed(bundleId: string): void
  isAllowed(bundleId: string): boolean
}

export function createPolicy(
  env: Readonly<Record<string, string | undefined>> = process.env,
): ComputerUsePolicy {
  const allowed = new Set(
    (env.CUA_ALLOWED_APPS ?? '')
      .split(',')
      .map((value) => value.trim())
      .filter(Boolean),
  )
  const allowAll = env.CUA_ALLOW_ALL_APPS === '1'

  const isAllowed = (bundleId: string): boolean => {
    if (HARD_DENIED_BUNDLE_IDS.has(bundleId)) return false
    return allowAll || allowed.has(bundleId)
  }

  return {
    isAllowed,
    assertAllowed(bundleId) {
      if (!isAllowed(bundleId)) {
        throw new ComputerUseError(
          'app_not_allowed',
          `App ${bundleId} is not allowed. Set CUA_ALLOWED_APPS or CUA_ALLOW_ALL_APPS=1.`,
        )
      }
    },
  }
}
