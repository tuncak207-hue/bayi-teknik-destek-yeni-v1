import { Injectable, ForbiddenException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';

@Injectable()
export class DocumentNotesService {
  constructor(private prisma: PrismaService) {}

  /** Bir dokümana ait, TÜM bayilerin notlarını görebilmesi (paylaşımlı bilgi birikimi) — ekip içi öğrenme için. */
  list(documentId: string) {
    return this.prisma.documentNote.findMany({
      where: { documentId },
      include: { user: { select: { id: true, firstName: true, lastName: true, company: true } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  create(documentId: string, userId: string, content: string) {
    return this.prisma.documentNote.create({
      data: { documentId, userId, content },
      include: { user: { select: { id: true, firstName: true, lastName: true, company: true } } },
    });
  }

  async remove(noteId: string, userId: string) {
    const note = await this.prisma.documentNote.findUnique({ where: { id: noteId } });
    if (!note) return { success: true };
    if (note.userId !== userId) {
      throw new ForbiddenException('Sadece kendi notunuzu silebilirsiniz.');
    }
    await this.prisma.documentNote.delete({ where: { id: noteId } });
    return { success: true };
  }
}
