import { Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';
import { EmbeddingService } from '../rag/embedding.service';

export interface KnowledgeMatch {
  id: string;
  problem: string;
  solution: string;
  productName: string | null;
  productModel: string | null;
  errorCode: string | null;
  similarity: number;
}

@Injectable()
export class KnowledgeBaseService {
  constructor(private prisma: PrismaService, private embedding: EmbeddingService) {}

  async create(
    engineerId: string,
    params: {
      problem: string;
      solution: string;
      productName?: string;
      productModel?: string;
      errorCode?: string;
      partUsed?: string;
      photoUrl?: string;
      description?: string;
    },
  ) {
    const entry = await this.prisma.knowledgeEntry.create({
      data: {
        engineerId,
        problem: params.problem,
        solution: params.solution,
        productName: params.productName,
        productModel: params.productModel,
        errorCode: params.errorCode,
        partUsed: params.partUsed,
        photoUrl: params.photoUrl,
        description: params.description,
      },
    });

    const textToEmbed = [params.problem, params.solution, params.productName, params.productModel, params.errorCode]
      .filter(Boolean)
      .join(' — ');
    const [vector] = await this.embedding.embedBatch([textToEmbed]);
    const vectorLiteral = `[${vector.join(',')}]`;

    await this.prisma.$executeRawUnsafe(
      `UPDATE knowledge_entries SET embedding = $1::vector WHERE id = $2`,
      vectorLiteral,
      entry.id,
    );

    return entry;
  }

  list() {
    return this.prisma.knowledgeEntry.findMany({
      orderBy: { createdAt: 'desc' },
      include: { engineer: { select: { firstName: true, lastName: true } } },
    });
  }

  async searchRelevant(query: string, limit = 3): Promise<KnowledgeMatch[]> {
    const [queryVector] = await this.embedding.embedBatch([query]);
    const vectorLiteral = `[${queryVector.join(',')}]`;

    const results: any[] = await this.prisma.$queryRawUnsafe(
      `SELECT id, problem, solution, "productName", "productModel", "errorCode",
              1 - (embedding <=> $1::vector) as similarity
       FROM knowledge_entries
       WHERE embedding IS NOT NULL
       ORDER BY embedding <=> $1::vector ASC
       LIMIT $2`,
      vectorLiteral,
      limit,
    );

    return results.filter((r) => r.similarity > 0.5);
  }
}
