import { Controller, Get, UseGuards, Req } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard, Roles } from '../auth/guards/jwt-auth.guard';
import { StatsService } from './stats.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('stats')
export class StatsController {
  constructor(private statsService: StatsService) {}

  @Roles('ADMIN')
  @Get('dashboard')
  dashboard() {
    return this.statsService.dashboard();
  }

  @Get('me')
  myStats(@Req() req: any) {
    return this.statsService.myStats(req.user.sub);
  }

  @Get('me/badges')
  myBadges(@Req() req: any) {
    return this.statsService.myBadges(req.user.sub);
  }

  @Get('me/year-in-review')
  yearInReview(@Req() req: any) {
    return this.statsService.yearInReview(req.user.sub);
  }
}
