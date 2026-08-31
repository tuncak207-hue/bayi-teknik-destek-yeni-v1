import { Injectable, Logger } from '@nestjs/common';

/**
 * Embedding sağlayıcısı soyutlaması.
 *
 * Not: Anthropic şu anda birinci taraf bir embedding modeli sunmuyor,
 * bu yüzden embedding için Voyage AI, OpenAI, ya da (kullanıcı isteğiyle
 * eklendi) kendi Ollama sunucunuzdaki ÜCRETSİZ bir açık kaynak model
 * kullanılabilir. Aşağıdaki servis EMBEDDING_PROVIDER env değişkenine
 * göre değiştirilebilir. Vektör boyutunu (dimension) prisma schema'daki
 * vector(1024) ile eşleştirmeyi unutmayın — "ollama" sağlayıcısı için
 * varsayılan model olan "bge-m3" de tam olarak 1024 boyut ürettiği için
 * herhangi bir şema/migration değişikliği GEREKMİYOR.
 */
@Injectable()
export class EmbeddingService {
  private readonly logger = new Logger(EmbeddingService.name);
  private readonly apiKey = process.env.EMBEDDING_API_KEY;
  private readonly provider = process.env.EMBEDDING_PROVIDER || 'voyage';
  private readonly model = process.env.EMBEDDING_MODEL || (this.provider === 'ollama' ? 'bge-m3' : 'voyage-3');
  private readonly ollamaBaseUrl = process.env.OLLAMA_BASE_URL || 'http://localhost:11434';

  async embed(text: string): Promise<number[]> {
    return this.embedBatch([text]).then((r) => r[0]);
  }

  async embedBatch(texts: string[]): Promise<number[][]> {
    if (this.provider === 'ollama') {
      return this.callWithRetry(() => this.callOllama(texts));
    }

    if (!this.apiKey) {
      throw new Error(
        'EMBEDDING_API_KEY tanımlı değil. .env dosyanıza embedding sağlayıcı anahtarını ekleyin.',
      );
    }

    if (this.provider === 'voyage') {
      return this.callWithRetry(() => this.callVoyage(texts));
    }

    if (this.provider === 'openai') {
      return this.callWithRetry(() => this.callOpenAi(texts));
    }

    throw new Error(`Bilinmeyen embedding sağlayıcı: ${this.provider}`);
  }

  /**
   * Voyage AI'nin ücretsiz kotası (ödeme yöntemi eklenmemiş hesaplarda)
   * dakikada sadece 3 istekle sınırlı — çoklu doküman yüklemesinde bu
   * sınıra çok kolay takılıyoruz. 429 (rate limit) hatası aldığımızda
   * sessizce vazgeçmek yerine artan bekleme süreleriyle (5sn, 15sn, 30sn,
   * 60sn) yeniden deniyoruz; kalıcı hatalarda (401, 400 vb.) hemen durup
   * hatayı yukarı fırlatıyoruz.
   */
  private async callWithRetry<T>(fn: () => Promise<T>, attempt = 1): Promise<T> {
    const maxAttempts = 3;
    // Gerçek rate-limit durumlarında kısa bekleme; kota/kimlik doğrulama
    // hatalarında tekrar denemeyip anında hata döndür.
    const delays = [1000, 3000];
    try {
      return await fn();
    } catch (err: any) {
      const message = String(err?.message ?? '');
      const isQuotaError =
        message.includes('insufficient_quota') ||
        message.includes('credit_balance_exhausted') ||
        message.includes('no credits remaining') ||
        err?.code === 'insufficient_quota' ||
        err?.code === 'credit_balance_exhausted';
      const isAuthOrClientError = err?.status === 400 || err?.status === 401 || err?.status === 403;
      const isRateLimit = err?.status === 429 || message.includes('429');

      // Bu hatalar kalıcıdır. Eski davranışta kota yetersizliği 5/15/30/60
      // saniye beklemelerine giriyor ve admin paneli gereksiz yere uzun süre
      // "İşleniyor" durumunda kalıyordu.
      if (isQuotaError || isAuthOrClientError || !isRateLimit || attempt >= maxAttempts) {
        throw err;
      }

      const delay = delays[attempt - 1] ?? 3000;
      this.logger.warn(
        `Embedding API hız sınırına takıldı, ${delay / 1000}sn beklenip tekrar denenecek (deneme ${attempt}/${maxAttempts}).`,
      );
      await new Promise((resolve) => setTimeout(resolve, delay));
      return this.callWithRetry(fn, attempt + 1);
    }
  }

  private async callOllama(texts: string[]): Promise<number[][]> {
    const res = await fetch(`${this.ollamaBaseUrl}/api/embed`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: this.model, input: texts }),
    });
    if (!res.ok) {
      const error: any = new Error(
        `Ollama embedding sunucusuna ulaşılamadı (${this.ollamaBaseUrl}): ${res.status} ${await res.text()}. ` +
          `"ollama pull ${this.model}" komutuyla modeli indirdiğinizden emin olun.`,
      );
      error.status = res.status;
      throw error;
    }
    const data: any = await res.json();
    return data.embeddings;
  }

  private async callVoyage(texts: string[]): Promise<number[][]> {
    const res = await fetch('https://api.voyageai.com/v1/embeddings', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ input: texts, model: this.model }),
    });
    if (!res.ok) {
      const error: any = new Error(`Embedding API hatası: ${res.status} ${await res.text()}`);
      error.status = res.status;
      throw error;
    }
    const data: any = await res.json();
    return data.data.map((d: any) => d.embedding);
  }

  private async callOpenAi(texts: string[]): Promise<number[][]> {
    const res = await fetch('https://api.openai.com/v1/embeddings', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ input: texts, model: this.model }),
    });
    if (!res.ok) {
      const error: any = new Error(`Embedding API hatası: ${res.status} ${await res.text()}`);
      error.status = res.status;
      throw error;
    }
    const data: any = await res.json();
    return data.data.map((d: any) => d.embedding);
  }
}
