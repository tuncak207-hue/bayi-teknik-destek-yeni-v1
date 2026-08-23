import { Injectable } from '@nestjs/common';
import { AIProvider, AIMessage, AICompletionResult } from './ai-provider.interface';

@Injectable()
export class AnthropicProvider implements AIProvider {
  private readonly apiKey = process.env.AI_API_KEY;
  private readonly model = process.env.AI_MODEL || 'claude-sonnet-4-6';

  async complete(
    messages: AIMessage[],
    opts: { maxTokens?: number; temperature?: number } = {},
  ): Promise<AICompletionResult> {
    if (!this.apiKey) {
      throw new Error('AI_API_KEY tanımlı değil. .env dosyasına Anthropic API anahtarınızı ekleyin.');
    }

    const systemMessage = messages.find((m) => m.role === 'system');
    const conversationMessages = messages.filter((m) => m.role !== 'system');

    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': this.apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: this.model,
        max_tokens: opts.maxTokens ?? 1500,
        temperature: opts.temperature ?? 0.2, // düşük sıcaklık: teknik cevaplarda uydurmayı azaltır
        system: systemMessage?.content,
        messages: conversationMessages.map((m) => ({
          role: m.role,
          content:
            typeof m.content === 'string'
              ? m.content
              : m.content.map((block) =>
                  block.type === 'text'
                    ? { type: 'text', text: block.text }
                    : {
                        type: 'image',
                        source: { type: 'base64', media_type: block.mediaType, data: block.data },
                      },
                ),
        })),
      }),
    });

    if (!res.ok) {
      throw new Error(`Anthropic API hatası: ${res.status} ${await res.text()}`);
    }

    const data: any = await res.json();
    const text = data.content
      .filter((b: any) => b.type === 'text')
      .map((b: any) => b.text)
      .join('\n');

    return { text, raw: data };
  }
}
