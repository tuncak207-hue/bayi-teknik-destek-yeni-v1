import { Controller, Get, Post, Patch, Delete, Param, Body, UseGuards, Req } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard, Roles } from '../auth/guards/jwt-auth.guard';
import { GroupsService } from './groups.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('groups')
export class GroupsController {
  constructor(private groupsService: GroupsService) {}

  @Get()
  list(@Req() req: any) {
    return this.groupsService.list(req.user.sub);
  }

  @Get(':id/conversation')
  getConversation(@Param('id') id: string) {
    return this.groupsService.getOrCreateConversation(id);
  }

  @Post(':id/join')
  join(@Req() req: any, @Param('id') id: string) {
    return this.groupsService.join(id, req.user.sub);
  }

  @Post(':id/leave')
  leave(@Req() req: any, @Param('id') id: string) {
    return this.groupsService.leave(id, req.user.sub);
  }

  @Roles('ADMIN')
  @Post()
  create(@Body('name') name: string, @Body('description') description?: string) {
    return this.groupsService.create(name, description);
  }

  @Roles('ADMIN')
  @Patch(':id')
  rename(@Param('id') id: string, @Body('name') name: string) {
    return this.groupsService.rename(id, name);
  }

  @Roles('ADMIN')
  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.groupsService.remove(id);
  }
}
