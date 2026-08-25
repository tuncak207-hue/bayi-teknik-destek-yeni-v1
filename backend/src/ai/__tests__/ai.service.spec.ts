import { Test } from '@nestjs/testing';
import { AiService } from '../ai.service';
import { RagSearchService } from '../../rag/rag-search.service';
import { KnowledgeBaseService } from '../../knowledge-base/knowledge-base.service';
import { TechnicalMemoryService } from '../technical-memory.service';
import { AI_PROVIDER } from '../providers/ai-provider.interface';

describe('AiService — uydurmama ve kaynak gösterme kuralları', () => {
  let service: AiService;
  let ragSearch: { search: jest.Mock };
  let provider: { complete: jest.Mock };

  beforeEach(async () => {
    ragSearch = { search: jest.fn() };
    provider = { complete: jest.fn() };

    const moduleRef = await Test.createTestingModule({
      providers: [
        AiService,
        { provide: RagSearchService, useValue: ragSearch },
        { provide: KnowledgeBaseService, useValue: { searchRelevant: jest.fn().mockResolvedValue([]) } },
        { provide: TechnicalMemoryService, useValue: {
          findMatch: jest.fn().mockResolvedValue({ tier: 'NEW' }),
          incrementUsage: jest.fn(),
        } },
        { provide: AI_PROVIDER, useValue: provider },
      ],
    }).compile();

    service = moduleRef.get(AiService);
  });

  it('alakalı doküman bulunduğunda ve model HIGH derse, sadece eşiği geçen chunk kaynak olarak döner', async () => {
    ragSearch.search.mockResolvedValue([
      {
        chunkId: 'c1',
        documentId: 'd1',
        documentTitle: 'MA8000 Installation Manual',
        brand: 'Honeywell',
        model: 'MA8000',
        version: 'V3',
        page: 42,
        content: 'Loop cihazları için terminal bağlantısı...',
        similarity: 0.91,
      },
      {
        chunkId: 'c2',
        documentId: 'd2',
        documentTitle: 'Alakasız Doküman',
        brand: 'X',
        model: 'Y',
        version: 'V1',
        page: 3,
        content: 'Konuyla alakasız içerik',
        similarity: 0.4, // eşiğin (0.72) altında -> kaynak olarak gösterilmemeli
      },
    ]);

    provider.complete.mockResolvedValue({
      text: '### Çözüm\nLoop hattını kontrol edin.\n\nCONFIDENCE: HIGH',
    });

    const answer = await service.answerTechnicalQuestion('MA8000 loop cihazları görünmüyor');

    expect(answer.confidence).toBe('HIGH');
    expect(answer.citations).toHaveLength(1);
    expect(answer.citations[0].chunkId).toBe('c1');
    expect(answer.answerMarkdown).not.toContain('CONFIDENCE');
  });

  it('hiç alakalı doküman bulunamazsa, model HIGH dese bile güven seviyesi LOW\'a zorlanır', async () => {
    ragSearch.search.mockResolvedValue([]); // Doküman bulunamadı

    provider.complete.mockResolvedValue({
      text: 'Bu bilgi üretici dokümanından doğrulanmamıştır.\n\nCONFIDENCE: HIGH',
    });

    const answer = await service.answerTechnicalQuestion('Bilinmeyen bir panel modeli hakkında soru');

    expect(answer.citations).toHaveLength(0);
    expect(answer.confidence).toBe('LOW'); // sistem HIGH'ı geçersiz kılar
  });

  it('model CONFIDENCE belirtmezse varsayılan olarak LOW kabul edilir (güvenli taraf)', async () => {
    ragSearch.search.mockResolvedValue([
      {
        chunkId: 'c1',
        documentId: 'd1',
        documentTitle: 'Doc',
        brand: 'B',
        model: 'M',
        version: 'V1',
        page: 1,
        content: '...',
        similarity: 0.8,
      },
    ]);
    provider.complete.mockResolvedValue({ text: 'Cevap metni ama CONFIDENCE etiketi yok.' });

    const answer = await service.answerTechnicalQuestion('soru');

    expect(answer.confidence).toBe('LOW');
  });

  it('RAG bağlamını sistem promptuna değil, kullanıcı mesajına ekler ve BAĞLAM etiketiyle gönderir', async () => {
    ragSearch.search.mockResolvedValue([
      {
        chunkId: 'c1',
        documentId: 'd1',
        documentTitle: 'MA8000 Installation Manual',
        brand: 'Honeywell',
        model: 'MA8000',
        version: 'V3',
        page: 42,
        content: 'Loop terminal bilgisi burada.',
        similarity: 0.95,
      },
    ]);
    provider.complete.mockResolvedValue({ text: 'Cevap\n\nCONFIDENCE: HIGH' });

    await service.answerTechnicalQuestion('MA8000 loop sorunu');

    const callArgs = provider.complete.mock.calls[0][0];
    const userMessage = callArgs.find((m: any) => m.role === 'user');
    expect(userMessage.content).toContain('BAĞLAM');
    expect(userMessage.content).toContain('Loop terminal bilgisi burada.');
    expect(userMessage.content).toContain('SORU: MA8000 loop sorunu');

    const systemMessage = callArgs.find((m: any) => m.role === 'system');
    expect(systemMessage.content).toContain('UYDURMAYACAKSIN');
  });
});
