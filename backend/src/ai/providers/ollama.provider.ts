import { Injectable } from '@nestjs/common';
import { AIProvider, AIMessage, AICompletionResult } from './ai-provider.interface';

/**
 * Kendi bilgisayarınızda (GPU'lu makine) çalışan, ücretsiz açık kaynak bir
 * model sağlayıcısı — Anthropic API'ye alternatif. Ollama kurulumu
 * gerektirir.
 *
 * OLLAMA_BASE_URL: Ollama sunucunuzun adresi.
 * OLLAMA_MODEL: Normal soru-cevap için kullanılan model (metin odaklı,
 * uzun talimatları takip edebilen bir model olmalı — örn. llama3.1:8b).
 * OLLAMA_VISION_MODEL: SADECE görsel/şema analizi için kullanılan,
 * ayrı ve daha küçük bir model (örn. moondream). Belirtilmezse
 * OLLAMA_MODEL kullanılır. Kullanıcı isteği üzerine ayrıldı — küçük,
 * görsel odaklı modeller (moondream gibi) uzun metin talimatlarını iyi
 * takip edemeyip boş cevap dönebiliyor; büyük modeller (llama3.1:8b
 * gibi) ise düşük VRAM'li kartlarda görsel işlerken zorlanıyor. İki
 * ayrı model kullanmak, her işi kendi güçlü olduğu modele veriyor.
 */
@Injectable()
export class OllamaProvider implements AIProvider {
  private readonly baseUrl = process.env.OLLAMA_BASE_URL || 'http://localhost:11434';
  private readonly model = process.env.OLLAMA_MODEL || 'llama3.1:8b';
  private readonly visionModel = process.env.OLLAMA_VISION_MODEL || this.model;

  async complete(
    messages: AIMessage[],
    opts: { maxTokens?: number; temperature?: number } = {},
  ): Promise<AICompletionResult> {
    const ollamaMessages = messages.map((m) => {
      if (typeof m.content === 'string') {
        return { role: m.role, content: m.content };
      }
      const textParts = m.content.filter((b) => b.type === 'text').map((b) => (b as any).text);
      const images = m.content.filter((b) => b.type === 'image').map((b) => (b as any).data);
      return {
        role: m.role,
        content: textParts.join('\n'),
        ...(images.length > 0 && { images }),
      };
    });

    // ÖNEMLİ DÜZELTME: Önceden hiç zaman aşımı (timeout) ayarlanmamıştı —
    // özellikle görsel (şema analizi) istekleri yerel modellerde çok uzun
    // sürebiliyor ve bağlantı erken kesiliyordu ("fetch failed" hatası).
    // Görsel içeren isteklerde 3 dakika, düz metinde 90 saniye tanıyoruz.
    const hasImages = ollamaMessages.some((m) => 'images' in m);
    const timeoutMs = hasImages ? 180_000 : 90_000;
    const modelToUse = hasImages ? this.visionModel : this.model;
    const controller = new AbortController();
    const timeoutHandle = setTimeout(() => controller.abort(), timeoutMs);

    let res: Response;
    try {
      res = await fetch(`${this.baseUrl}/api/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: modelToUse,
          messages: ollamaMessages,
          stream: false,
          options: {
            temperature: opts.temperature ?? 0.2,
            num_predict: opts.maxTokens ?? 1500,
          },
        }),
        signal: controller.signal,
      });
    } catch (e: any) {
      if (e?.name === 'AbortError') {
        throw new Error(`Ollama isteği ${timeoutMs / 1000} saniye içinde cevap vermedi (zaman aşımı).`);
      }
      throw e;
    } finally {
      clearTimeout(timeoutHandle);
    }

    if (!res.ok) {
      throw new Error(
        `Ollama sunucusuna ulaşılamadı (${this.baseUrl}): ${res.status} ${await res.text()}. ` +
          `Ollama'nın çalıştığından ve OLLAMA_BASE_URL'in doğru olduğundan emin olun.`,
      );
    }

    const data: any = await res.json();
    return { text: data.message?.content ?? '', raw: data };
  }
}
