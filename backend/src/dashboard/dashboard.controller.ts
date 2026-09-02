import { Controller, Get, UseGuards, Req } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard, Roles } from '../auth/guards/jwt-auth.guard';
import { DashboardService } from './dashboard.service';
import { AuthenticatedRequest } from '../common/types/authenticated-request';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('dashboard')
export class DashboardController {
  constructor(private dashboardService: DashboardService) {}

  @Get('for-me')
  forMe(@Req() req: AuthenticatedRequest) {
    return this.dashboardService.forDealer(req.user.sub);
  }

  // Kullanıcı isteği: "Bekleyen İşler Sayaç Rozeti"
  @Get('pending-actions-count')
  pendingActionsCount(@Req() req: AuthenticatedRequest) {
    return this.dashboardService.pendingActionsCount(req.user.sub);
  }

  @Roles('ADMIN')
  @Get('admin-priorities')
  adminPriorities() {
    return this.dashboardService.adminPriorities();
  }

  @Roles('ADMIN')
  @Get('admin-badge-counts')
  adminBadgeCounts() {
    return this.dashboardService.adminBadgeCounts();
  }
}
