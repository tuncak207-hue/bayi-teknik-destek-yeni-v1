import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

/**
 * Supabase Session/Transaction Pooler bağlantıları PgBouncer üzerinden
 * çalışabilir. Transaction pooling, Prisma'nın bağlantıya özel prepared
 * statement önbelleğiyle birlikte kullanıldığında PostgreSQL 26000
 * "prepared statement does not exist" hatası üretebilir.
 *
 * Render'daki mevcut DATABASE_URL doğrudan bağlantı olarak kalsa bile,
 * Supabase pooler host'larında Prisma'ya PgBouncer uyumluluğunu bildiriyoruz.
 * Migration komutları Prisma CLI tarafından DATABASE_URL üzerinden çalışır;
 * runtime istemcisi için bu normalizasyon login ve istatistik sorgularını da
 * aynı şekilde güvenli hâle getirir.
 */
function normalizeDatabaseUrl(rawUrl: string | undefined): string | undefined {
  if (!rawUrl) return rawUrl;

  try {
    const url = new URL(rawUrl);
    const isSupabasePooler = url.hostname.endsWith('.pooler.supabase.com');
    if (!isSupabasePooler) return rawUrl;

    url.searchParams.set('pgbouncer', 'true');
    if (!url.searchParams.has('connection_limit')) {
      url.searchParams.set('connection_limit', '1');
    }
    return url.toString();
  } catch {
    // Prisma will report the original malformed URL clearly at startup.
    return rawUrl;
  }
}

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  constructor() {
    super({
      datasources: {
        db: { url: normalizeDatabaseUrl(process.env.DATABASE_URL) },
      },
    });
  }

  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
