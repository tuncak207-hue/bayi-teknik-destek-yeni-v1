import { Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';

@Injectable()
export class AuditLogService {
  constructor(private prisma: PrismaService) {}

  /** Diğer servisler, bir admin işlemi yaptıklarında bunu çağırır. Hata verirse ana işlemi bozmasın diye sessizce yutulur. */
  async log(adminId: string, action: string, targetType?: string, targetId?: string, detail?: string) {
    try {
      await this.prisma.auditLog.create({ data: { adminId, action, targetType, targetId, detail } });
    } catch (e) {
      // İşlem günlüğü ikincil bir kayıt — burada bir hata olursa asıl
      // admin işlemini (örn. bayi onaylama) engellememeli.
    }
  }

  list(limit = 50) {
    return this.prisma.auditLog.findMany({
      orderBy: { createdAt: 'desc' },
      take: limit,
      include: { admin: { select: { firstName: true, lastName: true, email: true } } },
    });
  }
}
