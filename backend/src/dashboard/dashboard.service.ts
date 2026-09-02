import { Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';

@Injectable()
export class DashboardService {
  constructor(private prisma: PrismaService) {}

  async forDealer(dealerId: string) {
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const todayEnd = new Date();
    todayEnd.setHours(23, 59, 59, 999);

    const [todaysAppointments, openTickets, unreadNotifications, recentTraining] = await Promise.all([
      this.prisma.appointment.findMany({
        where: { dealerId, preferredStart: { gte: todayStart, lte: todayEnd }, status: { not: 'CANCELLED' } },
        orderBy: { preferredStart: 'asc' },
      }),
      this.prisma.supportTicket.findMany({
        where: { dealerId, status: { notIn: ['RESOLVED', 'CLOSED'] } },
        orderBy: [{ isEmergency: 'desc' }, { createdAt: 'desc' }],
      }),
      this.prisma.notification.count({ where: { userId: dealerId, readAt: null } }),
      this.prisma.trainingContent.count({ where: { createdAt: { gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) } } }),
    ]);

    const slaRiskTickets = openTickets.filter((t) => {
      if (!t.slaResolutionMinutes) return false;
      const deadline = t.createdAt.getTime() + t.slaResolutionMinutes * 60000;
      const remainingMinutes = (deadline - Date.now()) / 60000;
      return remainingMinutes < 120;
    });

    return {
      todaysAppointments,
      openTicketsCount: openTickets.length,
      slaRiskTicketsCount: slaRiskTickets.length,
      slaRiskTickets: slaRiskTickets.slice(0, 5),
      unreadNotifications,
      recentTrainingCount: recentTraining,
    };
  }

  /**
   * Kullanıcı isteği: "Bekleyen İşler Sayaç Rozeti" — Ana Sayfa'da tek bir
   * toplam sayı olarak, kullanıcının dikkatini bekleyen TÜM aksiyonları
   * (cevap bekleyen teklif, imza bekleyen rapor, okunmamış bildirim)
   * gösterir. Hiçbir yeni veri modeli gerekmiyor — mevcut tablolardan
   * sayılıyor.
   */
  async pendingActionsCount(dealerId: string) {
    const [pendingQuotes, unsignedMaintenance, unsignedCommissioning, unreadNotifications] = await Promise.all([
      this.prisma.quoteRequest.count({ where: { dealerId, status: 'SENT' } }),
      this.prisma.maintenanceRecord.count({ where: { createdByUserId: dealerId, signatureUrl: null } }),
      this.prisma.commissioningReport.count({ where: { dealerId, signatureUrl: null } }),
      this.prisma.notification.count({ where: { userId: dealerId, readAt: null } }),
    ]);
    return {
      total: pendingQuotes + unsignedMaintenance + unsignedCommissioning + unreadNotifications,
      breakdown: {
        pendingQuotes,
        unsignedMaintenance,
        unsignedCommissioning,
        unreadNotifications,
      },
    };
  }

  async adminPriorities() {
    const [emergencyTickets, escalatedTickets, pendingAppointments, openTicketsAll] = await Promise.all([
      this.prisma.supportTicket.findMany({
        where: { isEmergency: true, status: { notIn: ['RESOLVED', 'CLOSED'] } },
        include: { dealer: { select: { firstName: true, lastName: true, company: true } } },
      }),
      this.prisma.supportTicket.findMany({
        where: { status: 'ESCALATED' },
        include: { dealer: { select: { firstName: true, lastName: true, company: true } } },
      }),
      this.prisma.appointment.findMany({ where: { status: 'PENDING' } }),
      this.prisma.supportTicket.findMany({ where: { status: { notIn: ['RESOLVED', 'CLOSED'] } } }),
    ]);

    const slaRiskTickets = openTicketsAll.filter((t) => {
      if (!t.slaResolutionMinutes) return false;
      const deadline = t.createdAt.getTime() + t.slaResolutionMinutes * 60000;
      return (deadline - Date.now()) / 60000 < 120;
    });

    const priorities = [
      { label: 'Kritik (Acil) Teknik Kayıt', count: emergencyTickets.length, severity: 'critical' as const },
      { label: 'SLA Riski Taşıyan Kayıt', count: slaRiskTickets.length, severity: 'high' as const },
      { label: 'Yükseltilmiş (Eskale) Kayıt', count: escalatedTickets.length, severity: 'high' as const },
      { label: 'Onay Bekleyen Randevu', count: pendingAppointments.length, severity: 'medium' as const },
    ].filter((p) => p.count > 0);

    return {
      priorities,
      emergencyTickets,
      escalatedTickets,
      slaRiskTickets: slaRiskTickets.slice(0, 10),
    };
  }

  /**
   * Sidebar menü rozetleri için — kullanıcı isteği: "uygulamadan admin
   * paneline istek gönderdiğimde admin panelindeki kartlarda bildirim
   * olmalı". Her kategori için "dikkat gerektiren" (yeni/onay bekleyen)
   * kayıt sayısını döner.
   */
  async adminBadgeCounts() {
    const [pendingDealers, pendingAppointments, openSupportTickets, emergencyTickets, draftQuotes] = await Promise.all([
      this.prisma.user.count({ where: { role: 'DEALER', status: 'PENDING' } }),
      this.prisma.appointment.count({ where: { status: 'PENDING' } }),
      this.prisma.supportTicket.count({ where: { status: { in: ['OPEN', 'ESCALATED'] } } }),
      this.prisma.supportTicket.count({ where: { isEmergency: true, status: { notIn: ['RESOLVED', 'CLOSED'] } } }),
      this.prisma.quoteRequest.count({ where: { status: 'DRAFT' } }),
    ]);

    return {
      dealers: pendingDealers,
      appointments: pendingAppointments,
      supportTickets: openSupportTickets,
      emergencyTickets,
      quotes: draftQuotes,
    };
  }
}
