import { Controller, Get, Post, Patch, Delete, Param, Body, Query, UseGuards, Req } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CommunityService } from './community.service';
import { CreatePostDto, CreateCommentDto } from './dto/community.dto';

@UseGuards(JwtAuthGuard)
@Controller('community')
export class CommunityController {
  constructor(private communityService: CommunityService) {}

  @Get('posts')
  list(@Query('tag') tag?: string) {
    return this.communityService.listPosts(tag);
  }

  @Get('posts/:id')
  get(@Param('id') id: string) {
    return this.communityService.getPost(id);
  }

  @Post('posts')
  create(@Req() req: any, @Body() dto: CreatePostDto) {
    return this.communityService.createPost(req.user.sub, dto.title, dto.body, dto.tag);
  }

  @Delete('posts/:id')
  deletePost(@Req() req: any, @Param('id') id: string) {
    return this.communityService.deletePost(id, req.user.sub, req.user.role === 'ADMIN');
  }

  @Patch('posts/:id')
  updatePost(@Req() req: any, @Param('id') id: string, @Body() body: { title?: string; body?: string; tag?: string }) {
    return this.communityService.updatePost(id, req.user.sub, body);
  }

  @Post('posts/:id/comments')
  addComment(@Req() req: any, @Param('id') id: string, @Body() dto: CreateCommentDto) {
    return this.communityService.addComment(id, req.user.sub, dto.body);
  }

  @Delete('comments/:id')
  deleteComment(@Req() req: any, @Param('id') id: string) {
    return this.communityService.deleteComment(id, req.user.sub, req.user.role === 'ADMIN');
  }

  @Post('posts/:id/ask-ai')
  askAi(@Req() req: any, @Param('id') id: string) {
    return this.communityService.addAiAssistedComment(id, req.user.sub);
  }
}
