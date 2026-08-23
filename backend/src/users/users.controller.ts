import { Controller, Get, Patch, Delete, Post, Param, Body, Query, UseGuards, Req } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard, Roles } from '../auth/guards/jwt-auth.guard';
import { UsersService } from './users.service';
import { ChangePasswordDto, DeleteAccountDto } from './dto/account.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('users')
export class UsersController {
  constructor(private usersService: UsersService) {}

  @Get('dealers')
  listDealers(@Req() req: any) {
    return this.usersService.listActiveDealers(req.user.sub);
  }

  @Get('me')
  me(@Req() req: any) {
    return this.usersService.getProfile(req.user.sub);
  }

  @Patch('me')
  updateMe(@Req() req: any, @Body() body: any) {
    return this.usersService.updateProfile(req.user.sub, body);
  }

  @Patch('me/settings')
  updateSettings(@Req() req: any, @Body() body: any) {
    return this.usersService.updateSettings(req.user.sub, body);
  }

  @Patch('me/password')
  changePassword(@Req() req: any, @Body() dto: ChangePasswordDto) {
    return this.usersService.changePassword(req.user.sub, dto.currentPassword, dto.newPassword);
  }

  @Delete('me')
  deleteOwnAccount(@Req() req: any, @Body() dto: DeleteAccountDto) {
    return this.usersService.deleteOwnAccount(req.user.sub, dto.password);
  }

  @Post(':id/block')
  block(@Req() req: any, @Param('id') id: string) {
    return this.usersService.block(req.user.sub, id);
  }

  @Delete(':id/block')
  unblock(@Req() req: any, @Param('id') id: string) {
    return this.usersService.unblock(req.user.sub, id);
  }

  @Get('blocked')
  listBlocked(@Req() req: any) {
    return this.usersService.listBlocked(req.user.sub);
  }

  // ---- Admin ----
  @Roles('ADMIN')
  @Get()
  listAll(@Query('status') status?: 'PENDING' | 'ACTIVE' | 'SUSPENDED') {
    return this.usersService.listAll(status);
  }

  @Roles('ADMIN')
  @Patch(':id/approve')
  approve(@Req() req: any, @Param('id') id: string) {
    return this.usersService.approve(id, req.user.sub);
  }

  @Roles('ADMIN')
  @Patch(':id/suspend')
  suspend(@Req() req: any, @Param('id') id: string) {
    return this.usersService.suspend(id, req.user.sub);
  }

  /** Admin, herhangi bir bayinin temel bilgilerini düzenler. */
  @Roles('ADMIN')
  @Patch(':id')
  updateDealer(
    @Param('id') id: string,
    @Body() body: Partial<{ firstName: string; lastName: string; company: string; phone: string }>,
  ) {
    return this.usersService.updateProfile(id, body);
  }

  @Roles('ADMIN')
  @Delete(':id')
  remove(@Req() req: any, @Param('id') id: string) {
    return this.usersService.remove(id, req.user.sub);
  }

  @Roles('ADMIN')
  @Get('inactive')
  inactiveDealers() {
    return this.usersService.inactiveDealers();
  }

  @Get('sales-consultants')
  listSalesConsultants() {
    return this.usersService.listSalesConsultants();
  }

  @Roles('ADMIN')
  @Post('sales-consultants')
  createSalesConsultant(
    @Body() data: { firstName: string; lastName: string; email: string; phone: string; password: string },
  ) {
    return this.usersService.createSalesConsultant(data);
  }

  @Roles('ADMIN')
  @Delete('sales-consultants/:id')
  removeSalesConsultant(@Param('id') id: string) {
    return this.usersService.removeSalesConsultant(id);
  }

  @Patch('me/specialty-tags')
  updateSpecialtyTags(@Req() req: any, @Body('tags') tags: string[]) {
    return this.usersService.updateSpecialtyTags(req.user.sub, tags);
  }

  /** Admin: kullanıcıya süreli konuşma yasağı verir (mesajlaşma engellenir, hesabın geri kalanı etkilenmez). */
  @Roles('ADMIN')
  @Post(':id/chat-ban')
  chatBan(@Param('id') id: string, @Body('hours') hours: number) {
    return this.usersService.chatBan(id, hours);
  }

  /** Admin: kullanıcının konuşma yasağını erken kaldırır. */
  @Roles('ADMIN')
  @Delete(':id/chat-ban')
  liftChatBan(@Param('id') id: string) {
    return this.usersService.liftChatBan(id);
  }

  @Patch('me/notification-preferences')
  updateNotificationPreferences(@Req() req: any, @Body() preferences: Record<string, boolean>) {
    return this.usersService.updateNotificationPreferences(req.user.sub, preferences);
  }

  @Patch('me/quiet-hours')
  updateQuietHours(@Req() req: any, @Body() data: { enabled: boolean; start?: string; end?: string }) {
    return this.usersService.updateQuietHours(req.user.sub, data);
  }

  @Get('me/team')
  listTeamMembers(@Req() req: any) {
    return this.usersService.listTeamMembers(req.user.sub);
  }

  @Post('me/team')
  addTeamMember(
    @Req() req: any,
    @Body() data: { firstName: string; lastName: string; email: string; password: string },
  ) {
    return this.usersService.addTeamMember(req.user.sub, data);
  }

  @Delete('me/team/:id')
  removeTeamMember(@Req() req: any, @Param('id') id: string) {
    return this.usersService.removeTeamMember(req.user.sub, id);
  }
}
