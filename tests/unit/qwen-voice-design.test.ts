import { beforeEach, describe, expect, it, vi } from 'vitest'

const fetchMock = vi.hoisted(() => vi.fn())
vi.stubGlobal('fetch', fetchMock)

import { createVoiceDesign } from '@/lib/qwen-voice-design'

describe('createVoiceDesign', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.stubEnv('QWEN_VOICE_DESIGN_BASE_URL', 'https://voice.example.com')
  })

  it('reads voice design url from env config', async () => {
    fetchMock.mockResolvedValueOnce({
      ok: true,
      json: async () => ({
        output: {
          voice: 'voice-1',
          target_model: 'qwen-tts',
          preview_audio: {
            data: 'base64-audio',
            sample_rate: 24000,
            response_format: 'wav',
          },
        },
        usage: { count: 1 },
        request_id: 'req-1',
      }),
    })

    const result = await createVoiceDesign({
      voicePrompt: 'warm narrator',
      previewText: 'hello world',
    }, 'qwen-key')

    expect(result.success).toBe(true)
    expect(fetchMock).toHaveBeenCalledWith(
      'https://voice.example.com/api/v1/services/audio/tts/customization',
      expect.objectContaining({ method: 'POST' }),
    )
  })

  it('fails explicitly when qwen voice design env is missing', async () => {
    vi.stubEnv('QWEN_VOICE_DESIGN_BASE_URL', '')

    const result = await createVoiceDesign({
      voicePrompt: 'warm narrator',
      previewText: 'hello world',
    }, 'qwen-key')

    expect(result.success).toBe(false)
    expect(result.error).toContain('QWEN_VOICE_DESIGN_BASE_URL_MISSING')
  })
})
