import { Controller, Get, Post, Patch, Delete, Param, Body, UseGuards, Req } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard, Roles } from '../auth/guards/jwt-auth.guard';
import { AnnouncementsService } from './announcements.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('announcements')
export class AnnouncementsController {
  constructor(private announcementsService: AnnouncementsService) {}

  @Get()
  list() {
    return this.announcementsService.list();
  }

  /** Bayinin kendi (kaldırdıklarını hariç tutan) duyuru listesi. */
  @Get('mine')
  listForDealer(@Req() req: any) {
    return this.announcementsService.listForDealer(req.user.sub);
  }

  // ÖNEMLİ: Bu, sabit (literal) rotalardan SONRA, ':id' rotasından ÖNCE
  // tanımlanmalı — aksi halde "unacknowledged-critical" bir duyuru ID'si
  // gibi yorumlanıp yanlış metoda giderdi.
  @Get('unacknowledged-critical')
  listUnacknowledgedCritical(@Req() req: any) {
    return this.announcementsService.listUnacknowledgedCritical(req.user.sub);
  }

  @Get(':id')
  get(@Param('id') id: string) {
    return this.announcementsService.get(id);
  }

  /** Bayi, duyuruyu kendi listesinden kaldırır (herkes için silinmez). */
  @Delete(':id/dismiss')
  dismiss(@Req() req: any, @Param('id') id: string) {
    return this.announcementsService.dismissForUser(id, req.user.sub);
  }

  @Post(':id/acknowledge')
  acknowledge(@Req() req: any, @Param('id') id: string) {
    return this.announcementsService.acknowledge(id, req.user.sub);
  }

  /** Bayi duyuruyu açtığında (detaya girdiğinde) çağrılır. */
  @Post(':id/mark-read')
  markRead(@Req() req: any, @Param('id') id: string) {
    return this.announcementsService.markReadForUser(id, req.user.sub);
  }

  @Roles('ADMIN')
  @Get(':id/read-status')
  readStatus(@Param('id') id: string) {
    return this.announcementsService.readStatus(id);
  }

  @Roles('ADMIN')
  @Post()
  create(@Body('title') title: string, @Body('body') body: string, @Body('isCritical') isCritical?: boolean) {
    return this.announcementsService.create(title, body, isCritical);
  }

  @Roles('ADMIN')
  @Patch(':id')
  update(
    @Param('id') id: string,
    @Body('title') title?: string,
    @Body('body') body?: string,
    @Body('isCritical') isCritical?: boolean,
  ) {
    return this.announcementsService.update(id, { title, body, isCritical });
  }

  @Roles('ADMIN')
  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.announcementsService.remove(id);
  }
}
