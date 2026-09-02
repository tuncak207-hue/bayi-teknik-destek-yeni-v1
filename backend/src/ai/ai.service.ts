import { Inject, Injectable, Logger } from '@nestjs/common';
import { RagSearchService, RetrievedChunk } from '../rag/rag-search.service';
import { KnowledgeBaseService } from '../knowledge-base/knowledge-base.service';
import { TechnicalMemoryService } from './technical-memory.service';
import { AIProvider, AIMessage, AI_PROVIDER } from './providers/ai-provider.interface';

export interface TechnicalAnswer {
  answerMarkdown: string; // "### Çözüm / ### Kontrol Etmeniz Gerekenler" formatlı
  confidence: 'HIGH' | 'LOW';
  citations: Array<{
    chunkId: string;
    documentId: string;
    documentTitle: string;
    brand: string;
    model: string;
    version: string;
    page: number;
  }>;
  // AI Teknik Soru Hafızası — bu cevap geçmiş bir kayıttan mı geldi,
  // yoksa şimdi mi yeni oluşturuldu? Mobil arayüzde "Bu soru daha önce
  // yanıtlandı" / "Yeni teknik analiz yapıldı" göstergesi için.
  fromMemory: boolean;
  memoryId?: string;
}

// Kritik konular: bu konularda kaynak yoksa AI KESİN cevap veremez.
const CRITICAL_TOPICS_HINT = [
  'terminal numarası',
  'bağlantı şekli',
  'DIP switch',
  'kablo tipi',
  'loop kapasitesi',
  'cihaz limiti',
  'panel ayarı',
  'programlama',
  'röle bağlantısı',
  'enerji hesabı',
  'siren bağlantısı',
];

const SYSTEM_PROMPT = `Sen bir yangın alarm ve güvenlik kamera sistemleri TEKNİK DESTEK asistanısın.
Bu uygulama genel amaçlı bir sohbet botu DEĞİLDİR. Sadece şu konularda yardımcı olursun:
yangın alarm panelleri, dedektörler, modüller, sirenler, loop sistemleri, konfigürasyon,
devreye alma, arıza çözümü, kablolama, kamera sistemleri, NVR, VMS, network, kamera
konfigürasyonu, entegrasyon ve teknik ürün bilgileri.

EN ÖNEMLİ VE KESİN KURALIN — İSTİSNASI YOK:
Sana aşağıda "BAĞLAM" olarak verilen doküman parçaları DIŞINDA HİÇBİR teknik bilgi
KULLANMAYACAKSIN, UYDURMAYACAKSIN, kendi genel bilgine (eğitim verine) BAŞVURMAYACAKSIN.
Cevabın SADECE ve SADECE BAĞLAM'da yazılanlara dayanmalı.

Eğer BAĞLAM soruyu cevaplamak için yetersizse veya boşsa, kesinlikle tahmin etme,
kendi bilgini kullanma — SADECE şu cevabı ver:
"Yüklenmiş teknik dokümanlarda bu bilgi doğrulanamadı. İlgili ürün/model bilgisini
paylaşırsanız daha doğru bir arama yapabilirim."

Bu kural TÜM konular için geçerli, sadece şu kritik konularla sınırlı değil (ama özellikle
bunlarda kesinlikle dikkatli ol): ${CRITICAL_TOPICS_HINT.join(', ')}.

TAKİP SORUSU DAVRANIŞI:
Sana bazen "ÖNCEKİ SORU-CEVAP" diye bir bölüm verilecek. Bu, kullanıcının bir önceki
mesajı. Şimdiki SORU'yu oku ve KENDİN karar ver:
- Eğer şimdiki soru öncekiyle aynı konudaysa/devamıysa (örn. "peki ya X modelinde?",
  "bunu nasıl sıfırlarım?" gibi bir önceki cevaba atıfta bulunuyorsa), önceki cevabı
  BAĞLAM olarak da kullanıp devam niteliğinde cevap ver.
- Eğer şimdiki soru TAMAMEN FARKLI bir konudaysa (örn. önceki soru "loop kapasitesi"
  hakkındaydı, şimdiki soru "kamera çözünürlüğü" hakkında), ÖNCEKİ SORU-CEVAP'ı
  TAMAMEN GÖRMEZDEN GEL, sadece BAĞLAM'daki dokümanlara ve şimdiki SORU'ya odaklan.

CEVAP FORMATI (markdown, Türkçe, teknik terimleri gerekirse parantez içi İngilizce ile göster,
örn: "Topraklama hatası (Earth Fault)"):

### Çözüm
<kısa özet>

### Kontrol Etmeniz Gerekenler
1. ...
2. ...

Cevabının SONUNA, hangi güven seviyesinde olduğunu şu satırla belirt (tam olarak bu formatta,
başka bir yerde tekrar etme):
CONFIDENCE: HIGH  (BAĞLAM'daki dokümanlarla doğrudan doğrulanabiliyorsa)
CONFIDENCE: LOW   (BAĞLAM yetersizse, cevap veremiyorsan)

Kaynakça ayrıca sistem tarafından otomatik ekleneceği için sen "Kaynak:" bölümü YAZMA.`;

@Injectable()
export class AiService {
  private readonly logger = new Logger(AiService.name);

  constructor(
    private ragSearch: RagSearchService,
    private knowledgeBase: KnowledgeBaseService,
    private technicalMemory: TechnicalMemoryService,
    @Inject(AI_PROVIDER) private provider: AIProvider,
  ) {}

  async answerTechnicalQuestion(
    question: string,
    opts: {
      brand?: string;
      model?: string;
      imageBase64?: string;
      imageMediaType?: string;
      // Kullanıcı isteği: "ikinci soru bir önceki sorunun cevabı ile
      // ilgiliyse ona cevap versin değilse soruya cevap versin" — bir
      // önceki soru-cevap çifti buradan geliyor (varsa). AI, bu soruyu
      // öncekiyle ilgili mi (takip sorusu) yoksa tamamen yeni bir konu mu
      // olduğuna kendisi karar veriyor.
      previousQuestion?: string;
      previousAnswer?: string;
    } = {},
  ): Promise<TechnicalAnswer> {
    // ============================================================
    // TEKNİK HAFIZA KONTROL KATMANI — mevcut RAG akışının önüne
    // eklendi. Fotoğraflı sorularda hafıza atlanır (görsel içerik her
    // seferinde farklı olabilir, güvenilir eşleşme garantisi yok).
    // ============================================================
    if (!opts.imageBase64) {
      const memoryMatch = await this.technicalMemory.findMatch(question, {
        productName: opts.brand,
        productModel: opts.model,
      });

      if (memoryMatch.tier === 'VERIFIED' && memoryMatch.entry) {
        this.technicalMemory.incrementUsage(memoryMatch.entry.id).catch((err) => this.logger.warn(`Kullanım sayacı güncellenemedi: ${err}`));
        return {
          answerMarkdown: memoryMatch.entry.answerMarkdown,
          confidence: 'HIGH',
          citations: (memoryMatch.entry.citations as any) || [],
          fromMemory: true,
          memoryId: memoryMatch.entry.id,
        };
      }
      // SIMILAR ve NEW durumlarında (adım 6): normal akış devam eder —
      // SIMILAR'da da dokümanlar kontrol edilir, sadece VERIFIED'da
      // doküman taraması atlanır.
    }

    const [retrieved, knowledgeMatches] = await Promise.all([
      this.ragSearch.search(question, {
        brand: opts.brand,
        model: opts.model,
        limit: 6,
      }),
      // Teknik Bilgi Hafızası (#20) — mühendislerin daha önce kaydettiği
      // saha tecrübeleri de doküman aramasıyla BİRLİKTE bağlama ekleniyor.
      // Bulunamazsa (hiç kayıt yoksa) sessizce boş döner, mevcut akış
      // etkilenmez.
      this.knowledgeBase.searchRelevant(question, 3).catch(() => []),
    ]);

    const context = this.buildContextBlock(retrieved, knowledgeMatches);

    // Önceki soru-cevap varsa, AI'a "bu soru öncekiyle ilgili mi?" kararını
    // vermesi için ekliyoruz.
    const previousExchangeBlock =
      opts.previousQuestion && opts.previousAnswer
        ? `\n\nÖNCEKİ SORU-CEVAP (bu, bir önceki mesajdı — YALNIZCA şimdiki soru bununla İLGİLİYSE / bir devam/takip sorusuysa dikkate al, alakasızsa TAMAMEN GÖRMEZDEN GEL ve yeni soruyu bağımsız değerlendir):\nÖnceki Soru: ${opts.previousQuestion}\nÖnceki Cevap: ${opts.previousAnswer}`
        : '';

    const userContent: AIMessage['content'] = opts.imageBase64
      ? [
          { type: 'text', text: `BAĞLAM:\n${context}${previousExchangeBlock}\n\nSORU: ${question}` },
          { type: 'image', mediaType: opts.imageMediaType || 'image/jpeg', data: opts.imageBase64 },
        ]
      : `BAĞLAM:\n${context}${previousExchangeBlock}\n\nSORU: ${question}`;

    const messages: AIMessage[] = [
      { role: 'system', content: SYSTEM_PROMPT },
      { role: 'user', content: userContent },
    ];

    // Hız öncelikli: daha kısa maksimum cevap uzunluğu, üretim süresini
    // belirgin şekilde azaltıyor (yerel modellerde en büyük hız faktörü
    // budur — kullanıcı isteği: "çok hızlı cevap vermeli").
    const result = await this.provider.complete(messages, { maxTokens: 700, temperature: 0.2 });

    const { text, confidence } = this.extractConfidence(result.text);

    // Sadece gerçekten kullanılan (ve yeterince alakalı) chunk'ları kaynak olarak göster.
    // ÖNEMLİ: Bu eşik (0.72) Voyage AI'ın benzerlik puanlama ölçeğine göre
    // ayarlanmıştı. Farklı bir embedding sağlayıcısına (örn. Ollama/bge-m3)
    // geçildiğinde puan ölçeği değişebilir — aynı eşik, gerçekten alakalı
    // sonuçları da reddedebilir. Daha düşük, daha toleranslı bir eşiğe
    // çekildi; hangi sağlayıcı kullanılırsa kullanılsın makul çalışması
    // hedefleniyor.
    const usedCitations = retrieved
      .filter((c) => c.similarity >= 0.55)
      .slice(0, 4)
      .map((c) => ({
        chunkId: c.chunkId,
        documentId: c.documentId,
        documentTitle: c.documentTitle,
        brand: c.brand,
        model: c.model,
        version: c.version,
        page: c.page,
      }));

    // Bağlam çok zayıfsa (hiç alakalı chunk yoksa) güven seviyesini zorla LOW yap.
    const finalConfidence: 'HIGH' | 'LOW' = usedCitations.length === 0 ? 'LOW' : confidence;

    // Adım 7: Yeni oluşturulan cevap, gelecekteki benzer sorular için
    // hafızaya kaydedilir. Sadece HIGH güvenli ve fotoğrafsız sorular
    // kaydedilir — LOW güvenli ya da görsel tabanlı cevapları tekrar
    // kullanmak riskli olur.
    // ÖNEMLİ DÜZELTME: Önceden bu kayıt "fire and forget" idi ve oluşan
    // kaydın ID'si hiç geri döndürülmüyordu — mobil taraf, "bu cevabı
    // doğrula" butonuna basıldığında hangi kaydı işaretleyeceğini
    // bilemiyordu. Artık kayıt bekleniyor (await) ve memoryId yanıtla
    // birlikte dönüyor; kullanıcı isteği üzerine tüm bayiler bu cevabı
    // "doğru" olarak işaretleyebilecek.
    let newMemoryId: string | undefined;
    if (!opts.imageBase64 && finalConfidence === 'HIGH' && usedCitations.length > 0) {
      try {
        const entry = await this.technicalMemory.save({
          question,
          answerMarkdown: text,
          citations: usedCitations,
          productName: opts.brand,
          productModel: opts.model,
        });
        newMemoryId = entry?.id;
      } catch {
        // Hafızaya kayıt başarısız olursa cevabı ASLA engellemez.
      }
    }

    return { answerMarkdown: text, confidence: finalConfidence, citations: usedCitations, fromMemory: false, memoryId: newMemoryId };
  }

  private buildContextBlock(chunks: RetrievedChunk[], knowledgeMatches: { problem: string; solution: string; productName: string | null }[] = []): string {
    const docPart =
      chunks.length === 0
        ? '(İlgili doküman bulunamadı.)'
        : chunks
            .map(
              (c, i) =>
                `[${i + 1}] Marka: ${c.brand} | Model: ${c.model} | Doküman: ${c.documentTitle} (v${c.version}) | Sayfa: ${c.page}\n${c.content}`,
            )
            .join('\n\n---\n\n');

    if (knowledgeMatches.length === 0) return docPart;

    const knowledgePart = knowledgeMatches
      .map((k, i) => `[Saha Tecrübesi ${i + 1}]${k.productName ? ` Ürün: ${k.productName}` : ''}\nSorun: ${k.problem}\nÇözüm: ${k.solution}`)
      .join('\n\n---\n\n');

    return `${docPart}\n\n=== MÜHENDİS SAHA TECRÜBELERİ (benzer geçmiş vakalar) ===\n\n${knowledgePart}`;
  }

  private extractConfidence(text: string): { text: string; confidence: 'HIGH' | 'LOW' } {
    const match = text.match(/CONFIDENCE:\s*(HIGH|LOW)/i);
    const confidence = (match?.[1]?.toUpperCase() as 'HIGH' | 'LOW') || 'LOW';
    const cleaned = text.replace(/CONFIDENCE:\s*(HIGH|LOW)/i, '').trim();
    return { text: cleaned, confidence };
  }

  // ================= ÇOK DİLLİ ANLIK ÇEVİRİ (Sohbet İçi) =================
  // Ayrı bir çeviri API'si/anahtarı eklemeden, zaten kullandığımız AI
  // sağlayıcıdan yararlanıyoruz.
  async translate(text: string, targetLanguage: string): Promise<{ translatedText: string }> {
    const result = await this.provider.complete(
      [
        {
          role: 'system',
          content: `Sen bir çeviri asistanısın. Kullanıcının verdiği metni ${targetLanguage} diline çevir.
SADECE çeviriyi döndür — hiçbir açıklama, tırnak işareti veya ek metin ekleme.`,
        },
        { role: 'user', content: text },
      ],
      { maxTokens: 800, temperature: 0.1 },
    );
    return { translatedText: result.text.trim() };
  }
}
