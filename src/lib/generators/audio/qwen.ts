import { BaseAudioGenerator, AudioGenerateParams, GenerateResult } from '../base'
import { getProviderConfig } from '@/lib/api-config'
import { QWEN_TTS_PATH, resolveQwenConfiguredUrl } from '@/lib/qwen-api'

export class QwenTTSGenerator extends BaseAudioGenerator {
    protected async doGenerate(params: AudioGenerateParams): Promise<GenerateResult> {
        const { userId, text, voice = 'default', rate = 1.0 } = params

        const { apiKey } = await getProviderConfig(userId, 'qwen')
        const url = resolveQwenConfiguredUrl('QWEN_TTS_BASE_URL', QWEN_TTS_PATH)
        const body = {
            text,
            voice,
            rate,
        }

        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${apiKey}`,
            },
            body: JSON.stringify(body),
        })

        if (!response.ok) {
            const errorText = await response.text()
            throw new Error(`Qwen TTS 失败 (${response.status}): ${errorText}`)
        }

        const data = await response.json()
        const audioUrl = data.audio_url || data.output?.audio_url
        if (!audioUrl) {
            throw new Error('Qwen 未返回音频 URL')
        }

        return {
            success: true,
            audioUrl,
        }
    }
}
