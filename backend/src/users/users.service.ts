import { Injectable, NotFoundException, BadRequestException, UnauthorizedException, ForbiddenException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../common/prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AuditLogService } from '../audit-log/audit-log.service';

@Injectable()
export class UsersService {
  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
    private auditLog: AuditLogService,
  ) {}

  async listActiveDealers(excludeUserId: string) {
    const blocked = await this.prisma.block.findMany({
      where: { OR: [{ blockerId: excludeUserId }, { blockedId: excludeUserId }] },
    });
    const blockedIds = blocked.map((b) => (b.blockerId === excludeUserId ? b.blockedId : b.blockerId));

    return this.prisma.user.findMany({
      where: {
        role: 'DEALER',
        status: 'ACTIVE',
        id: { not: excludeUserId, notIn: blockedIds },
      },
      select: {
        id: true,
        firstName: true,
        lastName: true,
        company: true,
        avatarUrl: true,
      },
      orderBy: { company: 'asc' },
    });
  }

  // ---- Admin ----
  listAll(status?: 'PENDING' | 'ACTIVE' | 'SUSPENDED') {
    return this.prisma.user.findMany({
      where: { role: 'DEALER', ...(status ? { status } : {}) },
      orderBy: { createdAt: 'desc' },
    });
  }

  async approve(id: string, adminId?: string) {
    await this.ensureExists(id);
    const updated = await this.prisma.user.update({ where: { id }, data: { status: 'ACTIVE' } });

    // Önceden burada hiç bildirim gönderilmiyordu — bayi, hesabının
    // onaylandığını fark etmesi için körlemesine tekrar giriş denemek
    // zorunda kalıyordu.
    await this.notifications.notifyUser(
      id,
      'account_approved',
      'Hesabınız Onaylandı',
      'Hesabınız admin tarafından onaylandı, artık uygulamayı kullanabilirsiniz.',
    );
    if (adminId) await this.auditLog.log(adminId, 'dealer_approved', 'user', id, updated.company);
    return updated;
  }

  async suspend(id: string, adminId?: string) {
    await this.ensureExists(id);
    const updated = await this.prisma.user.update({ where: { id }, data: { status: 'SUSPENDED' } });
    if (adminId) await this.auditLog.log(adminId, 'dealer_suspended', 'user', id, updated.company);
    return updated;
  }

  async remove(id: string, adminId?: string) {
    const user = await this.ensureExists(id);
    await this.prisma.user.delete({ where: { id } });
    if (adminId) await this.auditLog.log(adminId, 'dealer_removed', 'user', id, user.company);
    return { deleted: true };
  }

  /**
   * Admin: kullanıcıya süreli konuşma yasağı verir. `hours` sayısı kadar
   * saat boyunca mesaj gönderemez (hesabın geri kalanı — giriş, doküman
   * görüntüleme vb. — etkilenmez). 1 saatten kısa yasaklar için ondalıklı
   * sayı da (örn. 0.5 = 30 dakika) kullanılabilir.
   */
  async chatBan(id: string, hours: number) {
    await this.ensureExists(id);
    if (!hours || hours <= 0) {
      throw new BadRequestException('Geçerli bir süre (saat) belirtmelisiniz.');
    }
    const until = new Date(Date.now() + hours * 60 * 60 * 1000);
    const updated = await this.prisma.user.update({ where: { id }, data: { chatBannedUntil: until } });

    const label = hours >= 24 ? `${Math.round(hours / 24)} gün` : hours >= 1 ? `${hours} saat` : `${Math.round(hours * 60)} dakika`;
    await this.notifications.notifyUser(
      id,
      'chat_banned',
      'Mesajlaşma Kısıtlaması',
      `Platform kurallarını ihlal eden bir mesajınız nedeniyle ${label} süreyle mesaj gönderemeyeceksiniz.`,
    );

    return updated;
  }

  async liftChatBan(id: string) {
    await this.ensureExists(id);
    return this.prisma.user.update({ where: { id }, data: { chatBannedUntil: null } });
  }

  /**
   * Bildirim tercihleri: hangi bildirim türünün push olarak gelmesini
   * istediğini bayi kendisi ayarlar. `preferences` örn:
   * { "new_message": true, "announcement": false }
   */
  async updateNotificationPreferences(userId: string, preferences: Record<string, boolean>) {
    await this.ensureExists(userId);
    return this.prisma.user.update({
      where: { id: userId },
      data: { notificationPreferences: preferences },
    });
  }

  /** Sessiz saatler (Do Not Disturb) ayarını günceller. */
  async updateQuietHours(userId: string, data: { enabled: boolean; start?: string; end?: string }) {
    await this.ensureExists(userId);
    return this.prisma.user.update({
      where: { id: userId },
      data: {
        quietHoursEnabled: data.enabled,
        quietHoursStart: data.start,
        quietHoursEnd: data.end,
      },
    });
  }

  // ---- Çoklu kullanıcılı bayi hesabı (Ekip Üyeleri) ----

  /** Bir firma sahibinin altındaki ekip üyelerini listeler. */
  async listTeamMembers(ownerId: string) {
    return this.prisma.user.findMany({
      where: { parentUserId: ownerId },
      select: { id: true, firstName: true, lastName: true, email: true, status: true, createdAt: true },
      orderBy: { createdAt: 'asc' },
    });
  }

  /**
   * Firma sahibi, kendi firması altında yeni bir ekip üyesi (teknisyen)
   * hesabı oluşturur. Ana hesap zaten onaylı/güvenilir olduğu için, alt
   * kullanıcılar admin onayı beklemeden doğrudan ACTIVE olarak açılır —
   * ama sadece firma sahibinin ekleyebileceği bir hesap olduğu için
   * güvenlik riski taşımaz (admin dilerse yine de tüm bayileri görebilir).
   */
  async addTeamMember(
    ownerId: string,
    data: { firstName: string; lastName: string; email: string; password: string },
  ) {
    const owner = await this.ensureExists(ownerId);
    if (owner.parentUserId) {
      throw new BadRequestException('Alt kullanıcılar kendi ekiplerine yeni üye ekleyemez.');
    }
    const existing = await this.prisma.user.findUnique({ where: { email: data.email } });
    if (existing) {
      throw new BadRequestException('Bu e-posta adresi zaten kullanılıyor.');
    }
    const passwordHash = await bcrypt.hash(data.password, 12);
    return this.prisma.user.create({
      data: {
        firstName: data.firstName,
        lastName: data.lastName,
        company: owner.company,
        phone: owner.phone,
        email: data.email,
        passwordHash,
        status: 'ACTIVE',
        parentUserId: ownerId,
      },
      select: { id: true, firstName: true, lastName: true, email: true, status: true, createdAt: true },
    });
  }

  async removeTeamMember(ownerId: string, memberId: string) {
    const member = await this.prisma.user.findUnique({ where: { id: memberId } });
    if (!member || member.parentUserId !== ownerId) {
      throw new ForbiddenException('Bu kullanıcı sizin ekibinize ait değil.');
    }
    await this.prisma.user.delete({ where: { id: memberId } });
    return { deleted: true };
  }

  /** Profil uzmanlık etiketleri — Bayiler listesinde kimin hangi konuda deneyimli olduğunu göstermek için. */
  async updateSpecialtyTags(userId: string, tags: string[]) {
    await this.ensureExists(userId);
    return this.prisma.user.update({ where: { id: userId }, data: { specialtyTags: tags } });
  }

  /** Admin: 30+ gündür giriş yapmamış aktif bayileri listeler ("bunlara ulaşmayı düşünün"). */
  async inactiveDealers() {
    const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    return this.prisma.user.findMany({
      where: {
        role: 'DEALER',
        status: 'ACTIVE',
        OR: [{ lastLoginAt: { lt: cutoff } }, { lastLoginAt: null }],
      },
      select: { id: true, firstName: true, lastName: true, company: true, email: true, lastLoginAt: true, createdAt: true },
      orderBy: { lastLoginAt: 'asc' },
    });
  }

  // ---- Profil ----
  async getProfile(id: string) {
    const user = await this.ensureExists(id);
    const { passwordHash, ...safe } = user;
    return safe;
  }

  async updateProfile(
    id: string,
    data: Partial<{ firstName: string; lastName: string; company: string; phone: string; avatarUrl: string }>,
  ) {
    await this.ensureExists(id);
    return this.prisma.user.update({ where: { id }, data });
  }

  async updateSettings(
    id: string,
    data: Partial<{ notificationsEnabled: boolean; language: string; darkMode: boolean }>,
  ) {
    await this.ensureExists(id);
    return this.prisma.user.update({ where: { id }, data });
  }

  async block(blockerId: string, blockedId: string) {
    return this.prisma.block.upsert({
      where: { blockerId_blockedId: { blockerId, blockedId } },
      create: { blockerId, blockedId },
      update: {},
    });
  }

  async unblock(blockerId: string, blockedId: string) {
    await this.prisma.block.deleteMany({ where: { blockerId, blockedId } });
    return { unblocked: true };
  }

  /** Kullanıcının engellediği bayilerin listesi. */
  async listBlocked(blockerId: string) {
    const blocks = await this.prisma.block.findMany({
      where: { blockerId },
      include: {
        blocked: { select: { id: true, firstName: true, lastName: true, company: true, avatarUrl: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
    return blocks.map((b) => b.blocked);
  }

  /** Kullanıcı kendi şifresini değiştirir; mevcut şifre doğrulanmadan işlem yapılmaz. */
  async changePassword(id: string, currentPassword: string, newPassword: string) {
    const user = await this.ensureExists(id);
    const valid = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!valid) throw new UnauthorizedException('Mevcut şifre hatalı.');
    if (newPassword.length < 8) {
      throw new BadRequestException('Yeni şifre en az 8 karakter olmalı.');
    }
    const passwordHash = await bcrypt.hash(newPassword, 12);
    await this.prisma.user.update({ where: { id }, data: { passwordHash } });
    return { success: true };
  }

  /**
   * Kullanıcı kendi hesabını siler. Satırı doğrudan silmek yerine
   * ANONİMLEŞTİRİYORUZ: geçmiş mesajlar/gönderiler diğer bayilerin
   * ekranında kırık referans olarak kalmaz, ama kişisel veriler
   * (KVKK gereği) temizlenir ve hesap artık giriş yapılamaz hâle gelir.
   */
  async deleteOwnAccount(id: string, password: string) {
    const user = await this.ensureExists(id);
    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) throw new UnauthorizedException('Şifre hatalı.');

    const randomPassword = await bcrypt.hash(`deleted-${id}-${Date.now()}`, 12);

    await this.prisma.user.update({
      where: { id },
      data: {
        firstName: 'Silinmiş',
        lastName: 'Kullanıcı',
        company: '',
        phone: '',
        email: `deleted-${id}@deleted.local`,
        passwordHash: randomPassword,
        avatarUrl: null,
        status: 'DELETED',
        fcmTokens: [],
        notificationsEnabled: false,
      },
    });

    return { deleted: true };
  }

  /** Admin: dolaylı, doğrudan aktif bir satış danışmanı hesabı oluşturur (onay beklemez). */
  async createSalesConsultant(data: { firstName: string; lastName: string; email: string; phone: string; password: string }) {
    const existing = await this.prisma.user.findUnique({ where: { email: data.email } });
    if (existing) {
      throw new BadRequestException('Bu e-posta adresi zaten kullanılıyor.');
    }
    const passwordHash = await bcrypt.hash(data.password, 12);
    return this.prisma.user.create({
      data: {
        firstName: data.firstName,
        lastName: data.lastName,
        company: 'ENTPA Mühendislik Hizmeti',
        phone: data.phone,
        email: data.email,
        passwordHash,
        role: 'SALES',
        status: 'ACTIVE',
      },
      select: { id: true, firstName: true, lastName: true, email: true, phone: true, createdAt: true },
    });
  }

  listSalesConsultants() {
    return this.prisma.user.findMany({
      where: { role: 'SALES', status: 'ACTIVE' },
      select: { id: true, firstName: true, lastName: true, email: true, avatarUrl: true },
      orderBy: { firstName: 'asc' },
    });
  }

  async removeSalesConsultant(id: string) {
    const user = await this.ensureExists(id);
    if (user.role !== 'SALES') throw new BadRequestException('Bu kullanıcı bir satış danışmanı değil.');
    await this.prisma.user.delete({ where: { id } });
    return { deleted: true };
  }

  private async ensureExists(id: string) {
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) throw new NotFoundException('Kullanıcı bulunamadı.');
    return user;
  }
}
