import { Controller, Get, UseGuards, Req } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard, Roles } from '../auth/guards/jwt-auth.guard';
import { DashboardService } from './dashboard.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('dashboard')
export class DashboardController {
  constructor(private dashboardService: DashboardService) {}

  @Get('for-me')
  forMe(@Req() req: any) {
    return this.dashboardService.forDealer(req.user.sub);
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
