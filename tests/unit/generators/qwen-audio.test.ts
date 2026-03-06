import { beforeEach, describe, expect, it, vi } from 'vitest'

const fetchMock = vi.hoisted(() => vi.fn())
const getProviderConfigMock = vi.hoisted(() => vi.fn(async () => ({
  id: 'qwen',
  name: 'Qwen',
  apiKey: 'qwen-key',
})))

vi.stubGlobal('fetch', fetchMock)
vi.mock('@/lib/api-config', () => ({
  getProviderConfig: getProviderConfigMock,
}))

import { QwenTTSGenerator } from '@/lib/generators/audio/qwen'

describe('QwenTTSGenerator', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.stubEnv('QWEN_TTS_BASE_URL', 'https://tts.example.com')
    getProviderConfigMock.mockResolvedValue({
      id: 'qwen',
      name: 'Qwen',
      apiKey: 'qwen-key',
    })
  })

  it('reads qwen tts url from env config', async () => {
    fetchMock.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ audio_url: 'https://cdn.example.com/audio.mp3' }),
    })

    const generator = new QwenTTSGenerator()
    const result = await generator.generate({
      userId: 'user-1',
      text: 'hello',
      voice: 'default',
      rate: 1,
    })

    expect(result).toEqual({ success: true, audioUrl: 'https://cdn.example.com/audio.mp3' })
    expect(fetchMock).toHaveBeenCalledWith('https://tts.example.com/api/v1/audio/tts', expect.objectContaining({
      method: 'POST',
      headers: expect.objectContaining({ Authorization: 'Bearer qwen-key' }),
    }))
  })

  it('fails explicitly when qwen tts env is missing', async () => {
    vi.stubEnv('QWEN_TTS_BASE_URL', '')

    const generator = new QwenTTSGenerator()
    const result = await generator.generate({
      userId: 'user-1',
      text: 'hello',
    })

    expect(result.success).toBe(false)
    expect(result.error).toContain('QWEN_TTS_BASE_URL_MISSING')
  })
})
