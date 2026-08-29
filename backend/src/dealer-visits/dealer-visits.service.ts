import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';
import { StorageService } from '../common/storage/storage.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class DealerVisitsService {
  constructor(
    private prisma: PrismaService,
    private storage: StorageService,
    private notifications: NotificationsService,
  ) {}

  async list(
    requestingUserId: string,
    isAdmin: boolean,
    filters: {
      from?: string;
      to?: string;
      salespersonId?: string;
      dealerId?: string;
      city?: string;
      visitType?: string;
      outcome?: string;
      needsFollowUp?: string;
      search?: string;
    },
  ) {
    const where: any = {};
    if (!isAdmin) where.salespersonId = requestingUserId;
    else if (filters.salespersonId) where.salespersonId = filters.salespersonId;

    if (filters.from || filters.to) {
      where.visitDate = {};
      if (filters.from) where.visitDate.gte = new Date(filters.from);
      if (filters.to) where.visitDate.lte = new Date(`${filters.to}T23:59:59`);
    }
    if (filters.dealerId) where.dealerId = filters.dealerId;
    if (filters.city) where.city = { contains: filters.city, mode: 'insensitive' };
    if (filters.visitType) where.visitType = filters.visitType;
    if (filters.outcome) where.outcome = filters.outcome;
    if (filters.needsFollowUp === 'true') where.needsFollowUp = true;

    if (filters.search) {
      const q = filters.search;
      where.OR = [
        { dealerNameFreeText: { contains: q, mode: 'insensitive' } },
        { contactName: { contains: q, mode: 'insensitive' } },
        { notes: { contains: q, mode: 'insensitive' } },
        { dealer: { company: { contains: q, mode: 'insensitive' } } },
        { salesperson: { firstName: { contains: q, mode: 'insensitive' } } },
        { salesperson: { lastName: { contains: q, mode: 'insensitive' } } },
      ];
    }

    return this.prisma.dealerVisit.findMany({
      where,
      include: {
        salesperson: { select: { id: true, firstName: true, lastName: true } },
        dealer: { select: { id: true, company: true } },
        attachments: true,
      },
      orderBy: { visitDate: 'desc' },
    });
  }

  async get(id: string, requestingUserId: string, isAdmin: boolean) {
    const visit = await this.prisma.dealerVisit.findUnique({
      where: { id },
      include: {
        salesperson: { select: { id: true, firstName: true, lastName: true } },
        dealer: { select: { id: true, company: true, firstName: true, lastName: true } },
        attachments: true,
      },
    });
    if (!visit) throw new NotFoundException('Ziyaret bulunamadı.');
    if (!isAdmin && visit.salespersonId !== requestingUserId) {
      throw new ForbiddenException('Bu ziyareti görüntüleme yetkiniz yok.');
    }
    return visit;
  }

  async create(salespersonId: string, dto: any) {
    const visit = await this.prisma.dealerVisit.create({
      data: {
        salespersonId,
        dealerId: dto.dealerId || null,
        dealerNameFreeText: dto.dealerNameFreeText || null,
        city: dto.city || null,
        visitDate: new Date(dto.visitDate),
        visitType: dto.visitType,
        contactName: dto.contactName || null,
        contactTitle: dto.contactTitle || null,
        contactPhone: dto.contactPhone || null,
        contactEmail: dto.contactEmail || null,
        topic: dto.topic || null,
        outcome: dto.outcome,
        notes: dto.notes,
        hasProject: !!dto.hasProject,
        projectName: dto.projectName || null,
        projectType: dto.projectType || null,
        estimatedAmount: dto.estimatedAmount ? Number(dto.estimatedAmount) : null,
        estimatedOrderDate: dto.estimatedOrderDate ? new Date(dto.estimatedOrderDate) : null,
        relatedProducts: dto.relatedProducts || null,
        competitorBrand: dto.competitorBrand || null,
        winProbability: dto.winProbability ? Number(dto.winProbability) : null,
        projectDescription: dto.projectDescription || null,
        needsFollowUp: !!dto.needsFollowUp,
        followUpDate: dto.followUpDate ? new Date(dto.followUpDate) : null,
        followUpAction: dto.followUpAction || null,
        followUpOwner: dto.followUpOwner || null,
        followUpNote: dto.followUpNote || null,
      },
    });

    if (visit.needsFollowUp) {
      const admins = await this.prisma.user.findMany({ where: { role: 'ADMIN' }, select: { id: true } });
      await Promise.all(
        admins.map((a) =>
          this.notifications.notifyUser(
            a.id,
            'ticket_created',
            'Takip Gerektiren Bayi Ziyareti',
            `${visit.dealerNameFreeText || 'Bir bayi'} ziyaretinde takip gerekiyor.`,
          ),
        ),
      );
    }

    return visit;
  }

  async update(id: string, requestingUserId: string, isAdmin: boolean, dto: any) {
    const existing = await this.get(id, requestingUserId, isAdmin);
    return this.prisma.dealerVisit.update({
      where: { id: existing.id },
      data: {
        ...(dto.dealerId !== undefined && { dealerId: dto.dealerId || null }),
        ...(dto.dealerNameFreeText !== undefined && { dealerNameFreeText: dto.dealerNameFreeText }),
        ...(dto.city !== undefined && { city: dto.city }),
        ...(dto.visitDate !== undefined && { visitDate: new Date(dto.visitDate) }),
        ...(dto.visitType !== undefined && { visitType: dto.visitType }),
        ...(dto.contactName !== undefined && { contactName: dto.contactName }),
        ...(dto.contactTitle !== undefined && { contactTitle: dto.contactTitle }),
        ...(dto.contactPhone !== undefined && { contactPhone: dto.contactPhone }),
        ...(dto.contactEmail !== undefined && { contactEmail: dto.contactEmail }),
        ...(dto.topic !== undefined && { topic: dto.topic }),
        ...(dto.outcome !== undefined && { outcome: dto.outcome }),
        ...(dto.notes !== undefined && { notes: dto.notes }),
        ...(dto.hasProject !== undefined && { hasProject: !!dto.hasProject }),
        ...(dto.projectName !== undefined && { projectName: dto.projectName }),
        ...(dto.projectType !== undefined && { projectType: dto.projectType }),
        ...(dto.estimatedAmount !== undefined && { estimatedAmount: dto.estimatedAmount ? Number(dto.estimatedAmount) : null }),
        ...(dto.estimatedOrderDate !== undefined && { estimatedOrderDate: dto.estimatedOrderDate ? new Date(dto.estimatedOrderDate) : null }),
        ...(dto.relatedProducts !== undefined && { relatedProducts: dto.relatedProducts }),
        ...(dto.competitorBrand !== undefined && { competitorBrand: dto.competitorBrand }),
        ...(dto.winProbability !== undefined && { winProbability: dto.winProbability ? Number(dto.winProbability) : null }),
        ...(dto.projectDescription !== undefined && { projectDescription: dto.projectDescription }),
        ...(dto.needsFollowUp !== undefined && { needsFollowUp: !!dto.needsFollowUp }),
        ...(dto.followUpDate !== undefined && { followUpDate: dto.followUpDate ? new Date(dto.followUpDate) : null }),
        ...(dto.followUpAction !== undefined && { followUpAction: dto.followUpAction }),
        ...(dto.followUpOwner !== undefined && { followUpOwner: dto.followUpOwner }),
        ...(dto.followUpNote !== undefined && { followUpNote: dto.followUpNote }),
        ...(dto.followUpDone !== undefined && { followUpDone: !!dto.followUpDone }),
      },
    });
  }

  async delete(id: string, requestingUserId: string, isAdmin: boolean) {
    const existing = await this.get(id, requestingUserId, isAdmin);
    await this.prisma.dealerVisit.delete({ where: { id: existing.id } });
    return { success: true };
  }

  async addAttachment(visitId: string, requestingUserId: string, isAdmin: boolean, file: Express.Multer.File) {
    await this.get(visitId, requestingUserId, isAdmin);
    const key = await this.storage.upload(file.buffer, file.originalname, file.mimetype, 'dealer-visits');
    return this.prisma.dealerVisitFile.create({
      data: { visitId, fileName: file.originalname, fileKey: key, mimeType: file.mimetype },
    });
  }

  async getAttachmentUrl(fileId: string, requestingUserId: string, isAdmin: boolean) {
    const file = await this.prisma.dealerVisitFile.findUnique({
      where: { id: fileId },
      select: { fileKey: true, visitId: true },
    });
    if (!file) throw new NotFoundException('Dosya bulunamadı.');
    await this.get(file.visitId, requestingUserId, isAdmin);
    return { url: await this.storage.getSignedUrl(file.fileKey) };
  }

  async dashboardSummary() {
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);

    const [visitsThisMonth, activeSalespeopleRows, needsFollowUp, projectsCreated, estimatedOpportunity, bySalesperson] = await Promise.all([
      this.prisma.dealerVisit.count({ where: { visitDate: { gte: startOfMonth } } }),
      this.prisma.dealerVisit.findMany({ where: { visitDate: { gte: startOfMonth } }, select: { salespersonId: true }, distinct: ['salespersonId'] }),
      this.prisma.dealerVisit.count({ where: { needsFollowUp: true, followUpDone: false } }),
      this.prisma.dealerVisit.count({ where: { hasProject: true, visitDate: { gte: startOfMonth } } }),
      this.prisma.dealerVisit.aggregate({ where: { hasProject: true, visitDate: { gte: startOfMonth } }, _sum: { estimatedAmount: true } }),
      this.prisma.dealerVisit.groupBy({
        by: ['salespersonId'],
        where: { visitDate: { gte: startOfMonth } },
        _count: { id: true },
      }),
    ]);

    const salespersonIds = bySalesperson.map((b) => b.salespersonId);
    const salespeople = await this.prisma.user.findMany({
      where: { id: { in: salespersonIds } },
      select: { id: true, firstName: true, lastName: true },
    });
    const nameMap = new Map(salespeople.map((s) => [s.id, `${s.firstName} ${s.lastName}`]));

    return {
      visitsThisMonth,
      activeSalespeople: activeSalespeopleRows.length,
      needsFollowUp,
      projectsCreated,
      estimatedOpportunity: estimatedOpportunity._sum.estimatedAmount || 0,
      bySalesperson: bySalesperson
        .map((b) => ({ salespersonId: b.salespersonId, name: nameMap.get(b.salespersonId) || '—', count: b._count.id }))
        .sort((a, b) => b.count - a.count),
    };
  }

  async salespersonPerformance(salespersonId: string) {
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const startOfWeek = new Date(now);
    startOfWeek.setDate(now.getDate() - now.getDay());
    startOfWeek.setHours(0, 0, 0, 0);

    const [total, thisMonth, thisWeek, positive, projectsCreated, followUpNeeded, opportunitySum, recentVisits] = await Promise.all([
      this.prisma.dealerVisit.count({ where: { salespersonId } }),
      this.prisma.dealerVisit.count({ where: { salespersonId, visitDate: { gte: startOfMonth } } }),
      this.prisma.dealerVisit.count({ where: { salespersonId, visitDate: { gte: startOfWeek } } }),
      this.prisma.dealerVisit.count({ where: { salespersonId, outcome: 'POSITIVE' } }),
      this.prisma.dealerVisit.count({ where: { salespersonId, hasProject: true } }),
      this.prisma.dealerVisit.count({ where: { salespersonId, needsFollowUp: true, followUpDone: false } }),
      this.prisma.dealerVisit.aggregate({ where: { salespersonId, hasProject: true }, _sum: { estimatedAmount: true } }),
      this.prisma.dealerVisit.findMany({
        where: { salespersonId },
        orderBy: { visitDate: 'desc' },
        take: 10,
        include: { dealer: { select: { company: true } } },
      }),
    ]);

    return {
      totalVisits: total,
      visitsThisMonth: thisMonth,
      visitsThisWeek: thisWeek,
      positiveOutcomes: positive,
      projectsCreated,
      needsFollowUp: followUpNeeded,
      estimatedOpportunity: opportunitySum._sum.estimatedAmount || 0,
      recentVisits,
    };
  }

  async dealerHistory(dealerId: string) {
    const visits = await this.prisma.dealerVisit.findMany({
      where: { dealerId },
      orderBy: { visitDate: 'desc' },
      include: { salesperson: { select: { firstName: true, lastName: true } } },
    });
    return {
      totalVisits: visits.length,
      lastVisitDate: visits[0]?.visitDate || null,
      visits,
    };
  }
}
