import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';

@Injectable()
export class GroupsService {
  constructor(private prisma: PrismaService) {}

  list(userId: string) {
    return this.prisma.group.findMany({
      include: {
        _count: { select: { members: true } },
        conversation: { select: { id: true } },
        members: { where: { userId }, select: { userId: true } },
      },
      orderBy: { createdAt: 'asc' },
    });
  }

  async create(name: string, description?: string) {
    const group = await this.prisma.group.create({ data: { name, description } });
    await this.prisma.conversation.create({
      data: { type: 'GROUP', title: name, groupId: group.id },
    });
    return group;
  }

  async rename(id: string, name: string) {
    await this.ensureExists(id);
    await this.prisma.conversation.updateMany({ where: { groupId: id }, data: { title: name } });
    return this.prisma.group.update({ where: { id }, data: { name } });
  }

  async remove(id: string) {
    await this.ensureExists(id);
    await this.prisma.group.delete({ where: { id } });
    return { deleted: true };
  }

  /**
   * Bir grubun konuşmasını döner — yoksa (geçmişteki bir migration/seed
   * tutarsızlığından dolayı eksik kalmışsa) kendi kendine oluşturur. Bu,
   * "gruba katıldım ama içine giremiyorum" sorununun kesin çözümü —
   * önceden join() konuşma yoksa sessizce hiçbir şey yapmıyordu.
   */
  async getOrCreateConversation(groupId: string) {
    const group = await this.ensureExists(groupId);
    let conversation = await this.prisma.conversation.findUnique({ where: { groupId } });
    if (!conversation) {
      conversation = await this.prisma.conversation.create({
        data: { type: 'GROUP', title: group.name, groupId },
      });
      // Grubun mevcut tüm üyelerini de bu yeni oluşturulan konuşmaya ekle.
      const members = await this.prisma.groupMember.findMany({ where: { groupId } });
      if (members.length > 0) {
        await this.prisma.conversationParticipant.createMany({
          data: members.map((m) => ({ conversationId: conversation!.id, userId: m.userId })),
          skipDuplicates: true,
        });
      }
    }
    return conversation;
  }

  async join(groupId: string, userId: string) {
    await this.ensureExists(groupId);
    await this.prisma.groupMember.upsert({
      where: { groupId_userId: { groupId, userId } },
      create: { groupId, userId },
      update: {},
    });
    // getOrCreateConversation kullanıyoruz — konuşma eksikse kendi kendine
    // oluşturur, artık asla "konuşma yok" durumuna düşülmüyor.
    const conversation = await this.getOrCreateConversation(groupId);
    await this.prisma.conversationParticipant.upsert({
      where: { conversationId_userId: { conversationId: conversation.id, userId } },
      create: { conversationId: conversation.id, userId },
      update: {},
    });
    return { joined: true };
  }

  async leave(groupId: string, userId: string) {
    await this.prisma.groupMember.deleteMany({ where: { groupId, userId } });
    const conversation = await this.prisma.conversation.findUnique({ where: { groupId } });
    if (conversation) {
      await this.prisma.conversationParticipant.deleteMany({
        where: { conversationId: conversation.id, userId },
      });
    }
    return { left: true };
  }

  private async ensureExists(id: string) {
    const group = await this.prisma.group.findUnique({ where: { id } });
    if (!group) throw new NotFoundException('Grup bulunamadı.');
    return group;
  }
}
