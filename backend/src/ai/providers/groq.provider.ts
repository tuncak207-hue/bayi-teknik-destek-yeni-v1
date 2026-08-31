import { Injectable } from '@nestjs/common';
import { AIProvider, AIMessage, AICompletionResult } from './ai-provider.interface';

/**
 * Kullanıcı isteği: "geçici olarak Groq kullanalım" — Anthropic hesabında
 * kredi tükendiğinde, ücretsiz katmanı olan Groq'a (bulutta çalışan, açık
 * kaynak modelleri çok hızlı servis eden bir sağlayıcı) geçici olarak
 * geçilebilmesi için eklendi. API formatı OpenAI ile uyumlu.
 */
@Injectable()
export class GroqProvider implements AIProvider {
  private readonly apiKey = process.env.GROQ_API_KEY;
  private readonly model = process.env.GROQ_MODEL || 'openai/gpt-oss-120b';

  async complete(
    messages: AIMessage[],
    opts: { maxTokens?: number; temperature?: number } = {},
  ): Promise<AICompletionResult> {
    if (!this.apiKey) {
      throw new Error('GROQ_API_KEY tanımlı değil. Render ortam değişkenlerine Groq API anahtarınızı ekleyin.');
    }

    // Groq, OpenAI'nin "chat/completions" formatını kullanıyor — sistem
    // mesajı ayrı tutulmuyor, normal bir mesaj gibi diziye dahil ediliyor.
    const openAiMessages = messages.map((m) => ({
      role: m.role,
      content:
        typeof m.content === 'string'
          ? m.content
          : m.content.map((block) =>
              block.type === 'text'
                ? { type: 'text', text: block.text }
                : {
                    type: 'image_url',
                    image_url: { url: `data:${block.mediaType};base64,${block.data}` },
                  },
            ),
    }));

    const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${this.apiKey}`,
      },
      body: JSON.stringify({
        model: this.model,
        max_tokens: opts.maxTokens ?? 1500,
        temperature: opts.temperature ?? 0.2,
        messages: openAiMessages,
      }),
    });

    if (!res.ok) {
      throw new Error(`Groq API hatası: ${res.status} ${await res.text()}`);
    }

    const data: any = await res.json();
    const text = data.choices?.[0]?.message?.content ?? '';
    return { text, raw: data };
  }
}
