import { Module } from '@nestjs/common';
import { AnthropicProvider } from './providers/anthropic.provider';
import { OllamaProvider } from './providers/ollama.provider';
import { GroqProvider } from './providers/groq.provider';
import { AI_PROVIDER } from './providers/ai-provider.interface';

/**
 * AI sağlayıcılarını (Anthropic/Ollama/Groq) hem AiModule hem RagModule
 * kullanabilsin diye ayrı, paylaşılan bir modülde topluyoruz — bu, iki
 * modülün birbirini import etmesiyle oluşacak döngüsel bağımlılığı
 * (RagModule şema açıklaması için AI sağlayıcısına ihtiyaç duyuyor,
 * AiModule zaten RagModule'ü kullanıyor) önlüyor.
 */
@Module({
  providers: [
    AnthropicProvider,
    OllamaProvider,
    GroqProvider,
    {
      provide: AI_PROVIDER,
      useFactory: (anthropic: AnthropicProvider, ollama: OllamaProvider, groq: GroqProvider) => {
        // Kullanıcı isteği: "geçici olarak Groq kullanalım" — AI_PROVIDER
        // ortam değişkeni "groq" olarak ayarlanınca (Anthropic'te kredi
        // tükendiğinde geçici bir çözüm olarak) Groq'a geçilebiliyor.
        if (process.env.AI_PROVIDER === 'ollama') return ollama;
        if (process.env.AI_PROVIDER === 'groq') return groq;
        return anthropic;
      },
      inject: [AnthropicProvider, OllamaProvider, GroqProvider],
    },
  ],
  exports: [AI_PROVIDER],
})
export class AiProvidersModule {}
