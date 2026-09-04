import { Inject, Injectable, Logger } from '@nestjs/common';
import { RagSearchService, RetrievedChunk } from '../rag/rag-search.service';
import { KnowledgeBaseService } from '../knowledge-base/knowledge-base.service';
import { TechnicalMemoryService } from './technical-memory.service';
import { SiteCrawlerService } from '../rag/site-crawler.service';
import { PrismaService } from '../common/prisma/prisma.service';
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
    private siteCrawler: SiteCrawlerService,
    private prisma: PrismaService,
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
    // Kullanıcı isteği: "model girdim, ayrıca marka girmem gerekmiyor,
    // model girsem yeterli olmalı" — mobil sohbet ekranında ayrı bir
    // marka/model seçme alanı yok, kullanıcı bu bilgiyi doğrudan SORU
    // METNİNİN içine yazıyor. Marka/model açıkça verilmemişse, soru
    // metninden OTOMATİK çıkarım yapılıyor — kayıtlı tüm ürünlerin
    // marka/model isimleri taranıp, sorunun içinde geçen (en spesifik/
    // en uzun) biri varsa kullanılıyor.
    if (!opts.brand && !opts.model) {
      const inferred = await this.inferBrandModelFromQuestion(question);
      if (inferred) {
        this.logger.log(`[Otomatik Çıkarım] Soru metninden tespit edildi: brand="${inferred.brand}" model="${inferred.model}"`);
        opts = { ...opts, ...inferred };
      }
    }

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
        this.technicalMemory.incrementUsage(memoryMatch.entry.id).catch(() => {});
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

    const [retrieved, knowledgeMatches, liveWebContent] = await Promise.all([
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
      // Kullanıcı isteği: "bir soru sorduğumda ilgili web sitesini
      // derinlemesine taramak gibi" — admin panelden eklenmiş, marka/
      // modelle eşleşen bir web linki varsa, önceden hazırlanmış statik
      // bir özet yerine SİTEYE O AN CANLI GİRİP arıyor (tıpkı bir web
      // araması yapar gibi). Zaman aşımı/hata olursa sessizce atlanır —
      // mevcut doküman tabanlı akış bundan ETKİLENMEZ.
      this.liveSearchRelevantUrl(opts.brand, opts.model).catch((err) => {
        this.logger.warn(`Canlı site taraması atlandı: ${err.message}`);
        return null;
      }),
    ]);

    const context = this.buildContextBlock(retrieved, knowledgeMatches) + (liveWebContent ? `\n\n--- CANLI WEB SİTESİ TARAMASI ---\n${liveWebContent}` : '');

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

  /**
   * Kullanıcı isteği: "bir soru sorduğumda ilgili web sitesini
   * derinlemesine taramak gibi" — marka/modelle eşleşen, admin panelden
   * eklenmiş bir web linki varsa, o siteye O AN girip (SiteCrawlerService
   * ile) menü/alt sayfaları da tarar, güncel içeriği döner. İnteraktif
   * bir sohbet akışında olduğu için (kullanıcı bekliyor), admin panelden
   * toplu ekleme sırasında kullanılan gevşek limitlerden DAHA SIKI
   * limitler kullanılıyor (daha az sayfa, daha kısa zaman aşımı).
   */
  /** Soru metninde kayıtlı ürün modellerinden biri geçiyor mu diye bakar (en uzun/spesifik eşleşme önceliklidir). */
  /**
   * Kullanıcı isteği: "ben sana xno model kameralar hangileri desem sen
   * bana hepsini yazar mısın" — katı metin eşleştirme (soru içinde TAM
   * OLARAK model adı geçiyor mu) yetersiz kaldı. Bunun yerine AI'nin
   * KENDİSİNE, kayıtlı markalar arasından soruyla İLGİLİ olanı
   * ANLAMSAL olarak seçtiriyoruz — tıpkı bir insanın "XNO kameralar"
   * sorusunun Hanwha'yla ilgili olduğunu bilmesi gibi.
   */
  private async inferBrandModelFromQuestion(question: string): Promise<{ brand?: string; model?: string } | null> {
    const products = await this.prisma.document.findMany({
      select: { brand: true, model: true },
      distinct: ['brand', 'model'],
    });
    if (products.length === 0) return null;

    const brandList: string[] = Array.from(new Set(products.map((p) => p.brand))).filter((b): b is string => Boolean(b));
    if (brandList.length === 0) return null;

    try {
      const result = await this.provider.complete(
        [
          {
            role: 'system',
            content: `Sen bir ürün-marka eşleştirme asistanısın. Sana kayıtlı marka isimlerinin bir listesi ve
bir kullanıcı sorusu verilecek. Soru, bu markalardan HANGİSİYLE İLGİLİYSE (ürün serisi, model
öneki, marka adının kendisi vb. üzerinden anlamsal olarak) o markanın adını AYNEN listedeki
gibi yaz. SADECE marka adını yaz, başka HİÇBİR şey ekleme. Hiçbiriyle ilgili değilse SADECE
"YOK" yaz.`,
          },
          {
            role: 'user',
            content: `Kayıtlı markalar: ${brandList.join(', ')}\n\nSoru: ${question}`,
          },
        ],
        { maxTokens: 30, temperature: 0 },
      );
      const answer = result.text.trim();
      const matchedBrand = brandList.find((b) => b!.toLowerCase() === answer.toLowerCase());
      if (!matchedBrand) return null;
      return { brand: matchedBrand };
    } catch (err) {
      this.logger.warn(`Marka çıkarımı için AI çağrısı başarısız: ${err}`);
      return null;
    }
  }

  private async liveSearchRelevantUrl(brand?: string, model?: string): Promise<string | null> {
    this.logger.log(`[Canlı Arama] Başladı — brand="${brand}" model="${model}"`);
    if (!brand && !model) {
      this.logger.log('[Canlı Arama] Marka/model verilmedi, atlanıyor.');
      return null;
    }

    const matchingDoc = await this.prisma.document.findFirst({
      where: {
        fileType: 'text/html',
        status: 'READY',
        ...(brand ? { brand: { contains: brand, mode: 'insensitive' } } : {}),
        ...(model ? { model: { contains: model, mode: 'insensitive' } } : {}),
      },
      orderBy: { updatedAt: 'desc' },
    });
    if (!matchingDoc) {
      this.logger.log(`[Canlı Arama] Eşleşen web linki bulunamadı (brand="${brand}", model="${model}").`);
      return null;
    }
    this.logger.log(`[Canlı Arama] Eşleşen kayıt bulundu: "${matchingDoc.title}" — ${matchingDoc.fileUrl}`);

    // Kullanıcı isteği: "7-8 tık uzakta olan sayfalar da olabilir" +
    // "bunu 8 sayfa ile kısıtlamamalısın" — AMA sohbet anlık (kullanıcı
    // bekliyor) çalıştığı için sunucu zaman aşımı riskiyle çelişiyordu.
    // Çözüm: DERİN tarama (8 seviyeye kadar) admin panelden link
    // eklerken ARKA PLANDA yapılıyor (zaman sınırı yok) — sohbet
    // sırasında ise o ÖNCEDEN HAZIRLANMIŞ kapsamlı içeriğe hızla
    // erişmek için burada daha SIĞ, HIZLI bir canlı tarama kullanılıyor.
    const pages = await this.siteCrawler.crawl(matchingDoc.fileUrl, {
      maxPages: 12,
      maxDepth: 3,
      pageTimeoutMs: 8_000,
      budgetMs: 45_000,
    });
    this.logger.log(`[Canlı Arama] Tarama tamamlandı — ${pages.length} sayfa alındı.`);
    if (pages.length === 0) return null;

    // AI'nin bağlam penceresini şişirmemek için toplam metni makul bir
    // uzunlukla sınırla (sayfa başına kabaca eşit pay ayırarak).
    const MAX_TOTAL_CHARS = 20_000;
    const perPageBudget = Math.floor(MAX_TOTAL_CHARS / pages.length);
    const result = pages.map((p) => `[${p.url}]\n${p.text.slice(0, perPageBudget)}`).join('\n\n');
    this.logger.log(`[Canlı Arama] Toplam ${result.length} karakter bağlama eklendi.`);
    return result;
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
}
