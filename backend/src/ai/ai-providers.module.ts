import { Module } from '@nestjs/common';
import { AnthropicProvider } from './providers/anthropic.provider';
import { OllamaProvider } from './providers/ollama.provider';
import { AI_PROVIDER } from './providers/ai-provider.interface';

/**
 * AI sağlayıcılarını (Anthropic/Ollama) hem AiModule hem RagModule
 * kullanabilsin diye ayrı, paylaşılan bir modülde topluyoruz — bu, iki
 * modülün birbirini import etmesiyle oluşacak döngüsel bağımlılığı
 * (RagModule şema açıklaması için AI sağlayıcısına ihtiyaç duyuyor,
 * AiModule zaten RagModule'ü kullanıyor) önlüyor.
 */
@Module({
  providers: [
    AnthropicProvider,
    OllamaProvider,
    {
      provide: AI_PROVIDER,
      useFactory: (anthropic: AnthropicProvider, ollama: OllamaProvider) => {
        return process.env.AI_PROVIDER === 'ollama' ? ollama : anthropic;
      },
      inject: [AnthropicProvider, OllamaProvider],
    },
  ],
  exports: [AI_PROVIDER],
})
export class AiProvidersModule {}
