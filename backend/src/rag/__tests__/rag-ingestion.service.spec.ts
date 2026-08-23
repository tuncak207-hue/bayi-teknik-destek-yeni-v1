import { Test } from '@nestjs/testing';
import { RagIngestionService } from '../rag-ingestion.service';
import { TextExtractionService } from '../text-extraction.service';
import { EmbeddingService } from '../embedding.service';
import { PrismaService } from '../../common/prisma/prisma.service';

describe('RagIngestionService — chunking ve embedding akışı', () => {
  let service: RagIngestionService;
  let extraction: { extract: jest.Mock };
  let embedding: { embedBatch: jest.Mock };
  let prisma: { $executeRawUnsafe: jest.Mock };

  beforeEach(async () => {
    extraction = { extract: jest.fn() };
    embedding = { embedBatch: jest.fn() };
    prisma = { $executeRawUnsafe: jest.fn().mockResolvedValue(undefined) };

    const moduleRef = await Test.createTestingModule({
      providers: [
        RagIngestionService,
        { provide: TextExtractionService, useValue: extraction },
        { provide: EmbeddingService, useValue: embedding },
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = moduleRef.get(RagIngestionService);
  });

  it('uzun bir sayfayı birden fazla chunk\'a böler ve her biri için embedding çağırır', async () => {
    const longText = 'A'.repeat(2000); // CHUNK_SIZE=800 -> en az 3 chunk beklenir
    extraction.extract.mockResolvedValue([{ page: 1, text: longText }]);
    embedding.embedBatch.mockImplementation(async (texts: string[]) => texts.map(() => new Array(1536).fill(0.01)));

    await service.processDocumentVersion('version-1', Buffer.from('fake-pdf'), 'application/pdf');

    expect(embedding.embedBatch).toHaveBeenCalled();
    const totalChunksEmbedded = embedding.embedBatch.mock.calls.reduce(
      (sum, call) => sum + call[0].length,
      0,
    );
    expect(totalChunksEmbedded).toBeGreaterThanOrEqual(3);
    expect(prisma.$executeRawUnsafe).toHaveBeenCalledTimes(totalChunksEmbedded);
  });

  it('boş sayfa/metin için embedding çağırmaz ve hata fırlatmaz', async () => {
    extraction.extract.mockResolvedValue([{ page: 1, text: '   ' }]);

    const pageCount = await service.processDocumentVersion('version-2', Buffer.from(''), 'text/plain');

    expect(embedding.embedBatch).not.toHaveBeenCalled();
    expect(pageCount).toBe(1);
  });

  it('her chunk için doğru sayfa numarasını pgvector INSERT sorgusuna geçirir', async () => {
    extraction.extract.mockResolvedValue([
      { page: 1, text: 'Kısa birinci sayfa metni.' },
      { page: 2, text: 'Kısa ikinci sayfa metni.' },
    ]);
    embedding.embedBatch.mockImplementation(async (texts: string[]) => texts.map(() => [0.1, 0.2]));

    await service.processDocumentVersion('version-3', Buffer.from('x'), 'text/plain');

    const insertedPages = prisma.$executeRawUnsafe.mock.calls.map((call) => call[3]); // page parametresi
    expect(insertedPages).toEqual(expect.arrayContaining([1, 2]));
  });
});
