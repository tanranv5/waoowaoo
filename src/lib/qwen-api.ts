export const QWEN_TTS_PATH = '/api/v1/audio/tts'
export const QWEN_VOICE_DESIGN_PATH = '/api/v1/services/audio/tts/customization'

function normalizeConfiguredBaseUrl(envKey: 'QWEN_TTS_BASE_URL' | 'QWEN_VOICE_DESIGN_BASE_URL'): URL {
  const baseUrl = (process.env[envKey] || '').trim()
  if (!baseUrl) {
    throw new Error(`${envKey}_MISSING`)
  }
  try {
    return new URL(baseUrl)
  } catch {
    throw new Error(`${envKey}_INVALID`)
  }
}

function joinPath(basePath: string, targetPath: string): string {
  if (basePath === targetPath) return basePath
  const normalizedBase = basePath === '/' ? '' : basePath.replace(/\/+$/, '')
  return `${normalizedBase}${targetPath}`
}

export function resolveQwenConfiguredUrl(
  envKey: 'QWEN_TTS_BASE_URL' | 'QWEN_VOICE_DESIGN_BASE_URL',
  targetPath: string,
): string {
  const parsed = normalizeConfiguredBaseUrl(envKey)
  parsed.pathname = joinPath(parsed.pathname, targetPath)
  return parsed.toString()
}
