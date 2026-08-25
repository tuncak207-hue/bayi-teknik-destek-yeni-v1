import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { ScheduleModule } from '@nestjs/schedule';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { DocumentsModule } from './documents/documents.module';
import { SlidesModule } from './slides/slides.module';
import { RagModule } from './rag/rag.module';
import { AiModule } from './ai/ai.module';
import { ChatModule } from './chat/chat.module';
import { GroupsModule } from './groups/groups.module';
import { CommunityModule } from './community/community.module';
import { NotificationsModule } from './notifications/notifications.module';
import { AnnouncementsModule } from './announcements/announcements.module';
import { SearchModule } from './search/search.module';
import { CalculatorsModule } from './calculators/calculators.module';
import { AppointmentsModule } from './appointments/appointments.module';
import { DealerVisitsModule } from './dealer-visits/dealer-visits.module';
import { FavoritesModule } from './favorites/favorites.module';
import { StatsModule } from './stats/stats.module';
import { CommissioningModule } from './commissioning/commissioning.module';
import { DocumentNotesModule } from './document-notes/document-notes.module';
import { MaintenanceModule } from './maintenance/maintenance.module';
import { CertificationsModule } from './certifications/certifications.module';
import { AuditLogModule } from './audit-log/audit-log.module';
import { BomModule } from './bom/bom.module';
import { TrainingModule } from './training/training.module';
import { WalletModule } from './wallet/wallet.module';
import { SupportTicketsModule } from './support-tickets/support-tickets.module';
import { DashboardModule } from './dashboard/dashboard.module';
import { KnowledgeBaseModule } from './knowledge-base/knowledge-base.module';
import { QuotesModule } from './quotes/quotes.module';
import { PrismaModule } from './common/prisma/prisma.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ThrottlerModule.forRoot([{ ttl: 60000, limit: 100 }]),
    ScheduleModule.forRoot(),
    PrismaModule,
    AuthModule,
    UsersModule,
    DocumentsModule,
    SlidesModule,
    RagModule,
    AiModule,
    ChatModule,
    GroupsModule,
    CommunityModule,
    NotificationsModule,
    AnnouncementsModule,
    SearchModule,
    CalculatorsModule,
    AppointmentsModule,
    DealerVisitsModule,
    FavoritesModule,
    StatsModule,
    CommissioningModule,
    DocumentNotesModule,
    MaintenanceModule,
    CertificationsModule,
    AuditLogModule,
    BomModule,
    TrainingModule,
    WalletModule,
    SupportTicketsModule,
    DashboardModule,
    KnowledgeBaseModule,
    QuotesModule,
  ],
  providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }],
})
export class AppModule {}
