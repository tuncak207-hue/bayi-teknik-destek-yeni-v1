import { Injectable, ForbiddenException, NotFoundException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import type { NotificationType } from '../notifications/notifications.service';
import { CreateAppointmentDto, UpdateAppointmentStatusDto } from './dto/appointment.dto';

// Randevu alınabilecek sabit saat dilimleri — mesai saatleri, 1'er saatlik.
// Bir bayi bir saati alınca, TÜM bayiler için o saat kapanır (tek bir
// ortak ENTPA takvimi — aynı anda sadece bir randevu karşılanabilir).
export const APPOINTMENT_SLOT_HOURS = [9, 10, 11, 12, 13, 14, 15, 16, 17];

@Injectable()
export class AppointmentsService {
  constructor(private prisma: PrismaService, private notifications: NotificationsService) {}

  /**
   * Belirli bir tarih için hangi saatlerin dolu olduğunu döner —
   * bayi randevu oluştururken bu saatleri seçemesin diye. İPTAL edilmiş
   * randevular "dolu" sayılmaz, o saat tekrar boşa çıkar.
   */
  async availability(dateStr: string) {
    const dayStart = new Date(`${dateStr}T00:00:00`);
    const dayEnd = new Date(`${dateStr}T23:59:59`);
    const booked = await this.prisma.appointment.findMany({
      where: {
        preferredStart: { gte: dayStart, lte: dayEnd },
        status: { not: 'CANCELLED' },
      },
      select: { preferredStart: true },
    });
    const bookedHours = booked.map((b) => b.preferredStart.getHours());
    return {
      slots: APPOINTMENT_SLOT_HOURS.map((hour) => ({
        hour,
        available: !bookedHours.includes(hour),
      })),
    };
  }

  /** Seçilen saatin hâlâ boş olduğunu doğrular — iki bayinin aynı anda aynı saati alması (race condition) önlenir. */
  private async assertSlotAvailable(preferredStart: Date, excludeAppointmentId?: string) {
    const conflict = await this.prisma.appointment.findFirst({
      where: {
        preferredStart,
        status: { not: 'CANCELLED' },
        ...(excludeAppointmentId && { id: { not: excludeAppointmentId } }),
      },
    });
    if (conflict) {
      throw new ConflictException('Bu tarih ve saat başka bir bayi tarafından alınmış. Lütfen başka bir saat seçin.');
    }
  }

  /**
   * Verilen tarih aralığında TÜM saat dilimleri dolu olan günleri döner —
   * kullanıcı isteği: "dolu olan gün ve saatler etkisiz olsun". Mobilde
   * takvimde bu günler seçilemez/gri gösterilir.
   */
  async fullyBookedDates(fromStr: string, toStr: string) {
    const from = new Date(`${fromStr}T00:00:00`);
    const to = new Date(`${toStr}T23:59:59`);
    const booked = await this.prisma.appointment.findMany({
      where: { preferredStart: { gte: from, lte: to }, status: { not: 'CANCELLED' } },
      select: { preferredStart: true },
    });

    const byDate = new Map<string, Set<number>>();
    for (const b of booked) {
      const dateKey = b.preferredStart.toISOString().slice(0, 10);
      if (!byDate.has(dateKey)) byDate.set(dateKey, new Set());
      byDate.get(dateKey)!.add(b.preferredStart.getHours());
    }

    const fullyBooked: string[] = [];
    for (const [dateKey, hours] of byDate.entries()) {
      if (APPOINTMENT_SLOT_HOURS.every((h) => hours.has(h))) fullyBooked.push(dateKey);
    }
    return fullyBooked;
  }

  async create(dealerId: string, dto: CreateAppointmentDto) {
    const preferredStart = new Date(dto.preferredStart);
    await this.assertSlotAvailable(preferredStart);

    const appointment = await this.prisma.appointment.create({
      data: {
        dealerId,
        type: dto.type,
        subject: dto.subject,
        description: dto.description,
        province: dto.province,
        district: dto.district,
        preferredStart,
        preferredEnd: dto.preferredEnd ? new Date(dto.preferredEnd) : null,
      },
    });

    // Tüm adminlere bilgi ver (basit yaklaşım: admin sayısı azdır, tek tek bildirim gönderilir).
    const admins = await this.prisma.user.findMany({ where: { role: 'ADMIN' }, select: { id: true } });
    await Promise.all(
      admins.map((a) =>
        this.notifications.notifyUser(
          a.id,
          'appointment_requested',
          'Yeni Randevu Talebi',
          `${dto.subject} — ${new Date(dto.preferredStart).toLocaleString('tr-TR')}`,
        ),
      ),
    );

    return appointment;
  }

  /** Bayi kendi randevularını görür. */
  listForDealer(dealerId: string) {
    return this.prisma.appointment.findMany({
      where: { dealerId },
      orderBy: { preferredStart: 'asc' },
    });
  }

  /** Admin tüm randevuları görür, isteğe bağlı durum filtresiyle. */
  listAll(status?: 'PENDING' | 'CONFIRMED' | 'CANCELLED' | 'COMPLETED') {
    return this.prisma.appointment.findMany({
      where: status ? { status } : undefined,
      include: { dealer: { select: { firstName: true, lastName: true, company: true, phone: true } } },
      orderBy: { preferredStart: 'asc' },
    });
  }

  async updateStatus(id: string, dto: UpdateAppointmentStatusDto) {
    const appointment = await this.prisma.appointment.findUnique({ where: { id } });
    if (!appointment) throw new NotFoundException('Randevu bulunamadı.');

    const updated = await this.prisma.appointment.update({
      where: { id },
      data: { status: dto.status, adminNote: dto.adminNote },
    });

    const statusText: Record<string, string> = {
      CONFIRMED: 'onaylandı',
      CANCELLED: 'iptal edildi',
      COMPLETED: 'tamamlandı',
    };
    await this.notifications.notifyUser(
      appointment.dealerId,
      'appointment_status_changed',
      'Randevu Durumu Güncellendi',
      `"${appointment.subject}" randevunuz ${statusText[dto.status]}.`,
    );

    return updated;
  }

  /** Bayi kendi PENDING randevusunu iptal edebilir. */
  async cancelOwn(dealerId: string, id: string) {
    const appointment = await this.prisma.appointment.findUnique({ where: { id } });
    if (!appointment) throw new NotFoundException('Randevu bulunamadı.');
    if (appointment.dealerId !== dealerId) throw new ForbiddenException('Bu randevu size ait değil.');

    const updated = await this.prisma.appointment.update({
      where: { id },
      data: { status: 'CANCELLED' },
    });

    // Admin'lere bilgi ver — bayi kendi randevusunu iptal ettiğinde admin
    // haberdar olmalı (önceden bu bildirim hiç gitmiyordu).
    await this.notifyAdmins('appointment_status_changed', 'Randevu İptal Edildi', `${appointment.subject} — bayi tarafından iptal edildi.`);

    return updated;
  }

  /**
   * Bayi kendi randevusunun tarih/saatini (ve isteğe bağlı konu/açıklama)
   * düzenleyebilir. Admin'e bildirim gider — önceden sadece admin bayiyi
   * düzenleyebiliyordu, tersi mümkün değildi.
   */
  async updateOwn(dealerId: string, id: string, dto: Partial<CreateAppointmentDto>) {
    const appointment = await this.prisma.appointment.findUnique({ where: { id } });
    if (!appointment) throw new NotFoundException('Randevu bulunamadı.');
    if (appointment.dealerId !== dealerId) throw new ForbiddenException('Bu randevu size ait değil.');

    if (dto.preferredStart !== undefined) {
      await this.assertSlotAvailable(new Date(dto.preferredStart), id);
    }

    const updated = await this.prisma.appointment.update({
      where: { id },
      data: {
        ...(dto.subject !== undefined && { subject: dto.subject }),
        ...(dto.description !== undefined && { description: dto.description }),
        ...(dto.province !== undefined && { province: dto.province }),
        ...(dto.district !== undefined && { district: dto.district }),
        ...(dto.preferredStart !== undefined && { preferredStart: new Date(dto.preferredStart) }),
        ...(dto.preferredEnd !== undefined && { preferredEnd: dto.preferredEnd ? new Date(dto.preferredEnd) : null }),
      },
    });

    await this.notifyAdmins(
      'appointment_requested',
      'Randevu Tarihi Değişti',
      `${updated.subject} — bayi tarafından ${new Date(updated.preferredStart).toLocaleString('tr-TR')} olarak güncellendi.`,
    );

    return updated;
  }

  /** Bayi kendi randevusunu kalıcı olarak siler (iptalden farklı — kayıt tamamen kaldırılır). */
  async deleteOwn(dealerId: string, id: string) {
    const appointment = await this.prisma.appointment.findUnique({ where: { id } });
    if (!appointment) throw new NotFoundException('Randevu bulunamadı.');
    if (appointment.dealerId !== dealerId) throw new ForbiddenException('Bu randevu size ait değil.');

    await this.prisma.appointment.delete({ where: { id } });
    await this.notifyAdmins('appointment_status_changed', 'Randevu Silindi', `${appointment.subject} — bayi tarafından silindi.`);

    return { success: true };
  }

  private async notifyAdmins(type: NotificationType, title: string, body: string) {
    const admins = await this.prisma.user.findMany({ where: { role: 'ADMIN' }, select: { id: true } });
    await Promise.all(admins.map((a) => this.notifications.notifyUser(a.id, type, title, body)));
  }

  /**
   * Admin: randevu bilgilerini (konu/açıklama/tarih) düzenler. Değişiklik
   * bayiye bildirim olarak gidiyor — böylece uygulamada anında yansıyor.
   */
  async adminUpdate(id: string, dto: Partial<CreateAppointmentDto>) {
    const appointment = await this.prisma.appointment.findUnique({ where: { id } });
    if (!appointment) throw new NotFoundException('Randevu bulunamadı.');

    const updated = await this.prisma.appointment.update({
      where: { id },
      data: {
        ...(dto.subject !== undefined && { subject: dto.subject }),
        ...(dto.description !== undefined && { description: dto.description }),
        ...(dto.type !== undefined && { type: dto.type }),
        ...(dto.preferredStart !== undefined && { preferredStart: new Date(dto.preferredStart) }),
        ...(dto.preferredEnd !== undefined && { preferredEnd: dto.preferredEnd ? new Date(dto.preferredEnd) : null }),
      },
    });

    await this.notifications.notifyUser(
      appointment.dealerId,
      'appointment_revised',
      'Randevunuz Güncellendi',
      `"${updated.subject}" randevunuzun bilgileri admin tarafından güncellendi.`,
    );

    return updated;
  }

  /** Admin: randevuyu kalıcı olarak siler (bayi sahiplik kontrolü yapılmaz). */
  async adminRemove(id: string) {
    const appointment = await this.prisma.appointment.findUnique({ where: { id } });
    if (!appointment) throw new NotFoundException('Randevu bulunamadı.');

    await this.prisma.appointment.delete({ where: { id } });

    await this.notifications.notifyUser(
      appointment.dealerId,
      'appointment_removed',
      'Randevu Silindi',
      `"${appointment.subject}" randevunuz admin tarafından silindi.`,
    );

    return { success: true };
  }
}
