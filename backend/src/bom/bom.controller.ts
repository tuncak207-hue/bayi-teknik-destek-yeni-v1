import { Controller, Get, Post, Patch, Delete, Param, Body, UseGuards, Req } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { BomService } from './bom.service';

@UseGuards(JwtAuthGuard)
@Controller('bom-lists')
export class BomController {
  constructor(private bomService: BomService) {}

  @Get()
  list(@Req() req: any) {
    return this.bomService.list(req.user.sub);
  }

  @Get(':id')
  get(@Req() req: any, @Param('id') id: string) {
    return this.bomService.get(id, req.user.sub);
  }

  @Post()
  create(
    @Req() req: any,
    @Body() data: { title: string; items: unknown; description?: string; province?: string; district?: string },
  ) {
    return this.bomService.create(req.user.sub, data.title, data.items, data.description, data.province, data.district);
  }

  @Patch(':id')
  update(
    @Req() req: any,
    @Param('id') id: string,
    @Body() data: { title: string; items: unknown; description?: string; province?: string; district?: string },
  ) {
    return this.bomService.update(id, req.user.sub, data.title, data.items, data.description, data.province, data.district);
  }

  @Delete(':id')
  remove(@Req() req: any, @Param('id') id: string) {
    return this.bomService.remove(id, req.user.sub);
  }
}
