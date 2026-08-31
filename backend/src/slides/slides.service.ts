import { Injectable } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';
import { StorageService } from '../common/storage/storage.service';

/**
 * Kullanıcı isteği: "uygulama açılırken ekranda slayt dönsün, bu
 * slaytları sürekli değiştirebilir durumda olayım." Admin panelden
 * yönetilen, mobil Ana Sayfa'da otomatik dönen tanıtım/duyuru slaytları.
 */
@Injectable()
export class SlidesService {
  constructor(
    private prisma: PrismaService,
    private storage: StorageService,
  ) {}

  /** Mobil uygulamanın çağırdığı, sadece AKTİF slaytları sıraya göre döndüren uç nokta. */
  async listActive() {
    const slides = await this.prisma.slide.findMany({
      where: { isActive: true },
      orderBy: { order: 'asc' },
    });
    return Promise.all(
      slides.map(async (s) => ({
        ...s,
        // Depolanan anahtar yerine, mobilin doğrudan gösterebileceği
        // geçici (imzalı) bir görsel URL'si üretiyoruz.
        imageUrl: await this.storage.getSignedUrl(s.imageUrl, 3600),
      })),
    );
  }

  /** Admin panelin çağırdığı, aktif/pasif tüm slaytları gösteren uç nokta. */
  async listAll() {
    const slides = await this.prisma.slide.findMany({ orderBy: { order: 'asc' } });
    return Promise.all(
      slides.map(async (s) => ({
        ...s,
        imageUrl: await this.storage.getSignedUrl(s.imageUrl, 3600),
      })),
    );
  }

  async create(
    file: Express.Multer.File,
    dto: { title?: string; subtitle?: string; linkUrl?: string; order?: number },
  ) {
    const fileKey = await this.storage.upload(file.buffer, file.originalname, file.mimetype, 'slides');
    // Video mu görsel mi olduğunu, yüklenen dosyanın MIME tipinden
    // otomatik belirliyoruz — admin panelde ayrıca bir seçim yapmaya
    // gerek kalmıyor.
    const mediaType = file.mimetype?.startsWith('video/') ? 'VIDEO' : 'IMAGE';
    return this.prisma.slide.create({
      data: {
        imageUrl: fileKey,
        mediaType,
        title: dto.title,
        subtitle: dto.subtitle,
        linkUrl: dto.linkUrl,
        order: dto.order ?? 0,
      },
    });
  }

  async update(id: string, dto: { title?: string; subtitle?: string; linkUrl?: string; order?: number; isActive?: boolean }) {
    return this.prisma.slide.update({ where: { id }, data: dto });
  }

  async delete(id: string) {
    const slide = await this.prisma.slide.findUnique({ where: { id } });
    if (slide) {
      await this.storage.delete(slide.imageUrl).catch(() => {});
    }
    return this.prisma.slide.delete({ where: { id } });
  }
}
