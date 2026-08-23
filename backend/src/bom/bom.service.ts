import { Injectable, ForbiddenException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';

@Injectable()
export class BomService {
  constructor(private prisma: PrismaService) {}

  list(userId: string) {
    return this.prisma.bomList.findMany({
      where: { userId },
      orderBy: { updatedAt: 'desc' },
    });
  }

  async get(id: string, userId: string) {
    const list = await this.prisma.bomList.findUnique({ where: { id } });
    if (!list) throw new NotFoundException('Malzeme listesi bulunamadi.');
    if (list.userId !== userId) throw new ForbiddenException('Bu listeye erisiminiz yok.');
    return list;
  }

  create(
    userId: string,
    title: string,
    items: unknown,
    description?: string,
    province?: string,
    district?: string,
  ) {
    return this.prisma.bomList.create({
      data: { userId, title, items: items as any, description, province, district },
    });
  }

  async update(
    id: string,
    userId: string,
    title: string,
    items: unknown,
    description?: string,
    province?: string,
    district?: string,
  ) {
    await this.get(id, userId);
    return this.prisma.bomList.update({
      where: { id },
      data: { title, items: items as any, description, province, district },
    });
  }

  async remove(id: string, userId: string) {
    await this.get(id, userId);
    await this.prisma.bomList.delete({ where: { id } });
    return { success: true };
  }
}
