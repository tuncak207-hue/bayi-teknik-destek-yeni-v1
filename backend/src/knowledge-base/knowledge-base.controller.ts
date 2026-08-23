import { Controller, Get, Post, Body, UseGuards, Req } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { KnowledgeBaseService } from './knowledge-base.service';

@UseGuards(JwtAuthGuard)
@Controller('knowledge-base')
export class KnowledgeBaseController {
  constructor(private knowledgeBaseService: KnowledgeBaseService) {}

  @Post()
  create(
    @Req() req: any,
    @Body()
    body: {
      problem: string;
      solution: string;
      productName?: string;
      productModel?: string;
      errorCode?: string;
      partUsed?: string;
      photoUrl?: string;
      description?: string;
    },
  ) {
    return this.knowledgeBaseService.create(req.user.sub, body);
  }

  @Get()
  list() {
    return this.knowledgeBaseService.list();
  }
}
