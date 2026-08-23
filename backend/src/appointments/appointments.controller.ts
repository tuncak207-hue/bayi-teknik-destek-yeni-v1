import { Controller, Get, Post, Patch, Delete, Body, Param, Query, UseGuards, Req } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard, Roles } from '../auth/guards/jwt-auth.guard';
import { AppointmentsService } from './appointments.service';
import { CreateAppointmentDto, UpdateAppointmentStatusDto } from './dto/appointment.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('appointments')
export class AppointmentsController {
  constructor(private appointmentsService: AppointmentsService) {}

  @Post()
  create(@Req() req: any, @Body() dto: CreateAppointmentDto) {
    return this.appointmentsService.create(req.user.sub, dto);
  }

  /** Bayi: kendi randevuları. Admin: hepsi (opsiyonel ?status= filtresiyle). */
  @Get()
  list(@Req() req: any, @Query('status') status?: 'PENDING' | 'CONFIRMED' | 'CANCELLED' | 'COMPLETED') {
    if (req.user.role === 'ADMIN') {
      return this.appointmentsService.listAll(status);
    }
    return this.appointmentsService.listForDealer(req.user.sub);
  }

  /** Belirli bir tarih için hangi saatlerin dolu/boş olduğu — randevu
   * oluştururken bayinin dolu saati seçememesi için. Tarih "YYYY-MM-DD"
   * formatında beklenir. */
  @Get('availability')
  availability(@Query('date') date: string) {
    return this.appointmentsService.availability(date);
  }

  /** Belirli bir tarih aralığında tüm saatleri dolu olan günler — takvimde bu günler pasif gösterilir. */
  @Get('fully-booked-dates')
  fullyBookedDates(@Query('from') from: string, @Query('to') to: string) {
    return this.appointmentsService.fullyBookedDates(from, to);
  }

  @Roles('ADMIN')
  @Patch(':id/status')
  updateStatus(@Param('id') id: string, @Body() dto: UpdateAppointmentStatusDto) {
    return this.appointmentsService.updateStatus(id, dto);
  }

  /** Admin: randevunun konu/açıklama/tarih bilgisini düzenler (revize eder). */
  @Roles('ADMIN')
  @Patch(':id')
  adminUpdate(@Param('id') id: string, @Body() dto: Partial<CreateAppointmentDto>) {
    return this.appointmentsService.adminUpdate(id, dto);
  }

  /** Admin: randevuyu kalıcı olarak siler (dealerId kontrolü olmadan). */
  @Roles('ADMIN')
  @Delete(':id/admin')
  adminRemove(@Param('id') id: string) {
    return this.appointmentsService.adminRemove(id);
  }

  @Delete(':id')
  cancelOwn(@Req() req: any, @Param('id') id: string) {
    return this.appointmentsService.cancelOwn(req.user.sub, id);
  }

  /** Bayi kendi randevusunun tarih/saatini düzenler. */
  @Patch(':id/own')
  updateOwn(@Req() req: any, @Param('id') id: string, @Body() dto: Partial<CreateAppointmentDto>) {
    return this.appointmentsService.updateOwn(req.user.sub, id, dto);
  }

  /** Bayi kendi randevusunu kalıcı olarak siler (iptalden farklı). */
  @Delete(':id/own-delete')
  deleteOwn(@Req() req: any, @Param('id') id: string) {
    return this.appointmentsService.deleteOwn(req.user.sub, id);
  }
}
