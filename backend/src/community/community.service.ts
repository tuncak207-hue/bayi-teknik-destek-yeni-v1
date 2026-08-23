import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';
import { AiService } from '../ai/ai.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class CommunityService {
  constructor(
    private prisma: PrismaService,
    private aiService: AiService,
    private notifications: NotificationsService,
  ) {}

  listPosts(tag?: string) {
    return this.prisma.communityPost.findMany({
      where: tag ? { tag } : undefined,
      include: {
        author: { select: { id: true, firstName: true, lastName: true, company: true, avatarUrl: true } },
        _count: { select: { comments: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getPost(id: string) {
    const post = await this.prisma.communityPost.findUnique({
      where: { id },
      include: {
        author: { select: { id: true, firstName: true, lastName: true, company: true, avatarUrl: true } },
        comments: {
          include: { author: { select: { id: true, firstName: true, lastName: true, avatarUrl: true } } },
          orderBy: { createdAt: 'asc' },
        },
      },
    });
    if (!post) throw new NotFoundException('Gönderi bulunamadı.');
    return post;
  }

  createPost(authorId: string, title: string, body: string, tag?: string) {
    return this.prisma.communityPost.create({ data: { authorId, title, body, tag } });
  }

  async addComment(postId: string, authorId: string, body: string) {
    const post = await this.getPost(postId);
    const comment = await this.prisma.communityComment.create({
      data: { postId, authorId, body, isAI: false },
    });

    // Gönderi sahibine yorum bildirimi (kendi gönderisine kendisi yorum yaparsa gerek yok).
    if (post.authorId !== authorId) {
      await this.notifications.notifyUser(
        post.authorId,
        'reply',
        `"${post.title}" gönderinize yorum yapıldı`,
        body.length > 80 ? `${body.slice(0, 80)}...` : body,
        { postId },
      );
    }

    return comment;
  }

  /**
   * Bayi "Bayilere Sor" gönderisinde AI'dan da yardım isteyebilir.
   * Bu YANIT üretici dokümanı gibi SUNULMAZ; "AI destekli topluluk cevabı"
   * olarak, kaynak varsa kaynağıyla birlikte, isAI=true olarak işaretlenir.
   */
  async addAiAssistedComment(postId: string, requestingUserId: string) {
    const post = await this.getPost(postId);
    const answer = await this.aiService.answerTechnicalQuestion(`${post.title}\n${post.body}`, {});

    const sourceLine =
      answer.citations.length > 0
        ? `\n\n_Kaynak: ${answer.citations.map((c) => `${c.documentTitle} (s.${c.page})`).join(', ')}_`
        : `\n\n_Bu konuda doğrulayabildiğim bir üretici dokümanı bulunamadı._`;

    return this.prisma.communityComment.create({
      data: {
        postId,
        authorId: requestingUserId,
        body: `**[AI destekli topluluk cevabı — üretici dokümanı ile aynı seviyede değildir]**\n\n${answer.answerMarkdown}${sourceLine}`,
        isAI: true,
      },
    });
  }

  /** Gönderiyi yazarı ya da admin silebilir. Yorumları da birlikte silinir. */
  async deletePost(postId: string, requestingUserId: string, isAdmin: boolean) {
    const post = await this.prisma.communityPost.findUnique({ where: { id: postId } });
    if (!post) return { success: true };
    if (post.authorId !== requestingUserId && !isAdmin) {
      throw new ForbiddenException('Sadece kendi gönderinizi silebilirsiniz.');
    }
    await this.prisma.communityComment.deleteMany({ where: { postId } });
    await this.prisma.communityPost.delete({ where: { id: postId } });
    return { success: true };
  }

  /** Gönderiyi sadece yazarı düzenleyebilir. */
  async updatePost(postId: string, requestingUserId: string, params: { title?: string; body?: string; tag?: string }) {
    const post = await this.prisma.communityPost.findUnique({ where: { id: postId } });
    if (!post) throw new NotFoundException('Gönderi bulunamadı.');
    if (post.authorId !== requestingUserId) {
      throw new ForbiddenException('Sadece kendi gönderinizi düzenleyebilirsiniz.');
    }
    return this.prisma.communityPost.update({
      where: { id: postId },
      data: {
        ...(params.title !== undefined && { title: params.title }),
        ...(params.body !== undefined && { body: params.body }),
        ...(params.tag !== undefined && { tag: params.tag }),
      },
    });
  }

  /** Yorumu yazarı ya da admin silebilir. */
  async deleteComment(commentId: string, requestingUserId: string, isAdmin: boolean) {
    const comment = await this.prisma.communityComment.findUnique({ where: { id: commentId } });
    if (!comment) return { success: true };
    if (comment.authorId !== requestingUserId && !isAdmin) {
      throw new ForbiddenException('Sadece kendi yorumunuzu silebilirsiniz.');
    }
    await this.prisma.communityComment.delete({ where: { id: commentId } });
    return { success: true };
  }
}
