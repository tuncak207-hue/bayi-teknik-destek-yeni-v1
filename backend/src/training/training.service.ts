import { Injectable, Inject } from '@nestjs/common';
import { PrismaService } from '../common/prisma/prisma.service';
import { StorageService } from '../common/storage/storage.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AIProvider, AI_PROVIDER } from '../ai/providers/ai-provider.interface';

@Injectable()
export class TrainingService {
  constructor(
    private prisma: PrismaService,
    private storage: StorageService,
    private notifications: NotificationsService,
    @Inject(AI_PROVIDER) private aiProvider: AIProvider,
  ) {}

  /**
   * Kullanıcı isteği: "eğitimi tamamlamak için 1 gün verelim, geri sayaç
   * işlesin..." — bir eğitimin bitiş süresini (deadline) ve o an itibarıyla
   * durumunu (tamamlandı / devam ediyor / süresi doldu) hesaplayan ortak
   * yardımcı. Ayrı bir arka plan işi (cron) GEREKMİYOR — durum her zaman
   * isteğin geldiği anda, deadline'a göre hesaplanıyor.
   */
  private computeStatus(
    training: { requiresCompletion: boolean; createdAt: Date; deadlineHours: number },
    completedAt: Date | null,
  ): { status: string | null; deadline: Date | null; completedAt: Date | null } {
    if (completedAt) return { status: 'COMPLETED', deadline: null, completedAt };
    if (!training.requiresCompletion) return { status: null, deadline: null, completedAt: null };
    const deadline = new Date(training.createdAt.getTime() + training.deadlineHours * 3600 * 1000);
    const status = new Date() >= deadline ? 'EXPIRED' : 'PENDING';
    return { status, deadline, completedAt: null };
  }

  async list(userId: string) {
    const contents = await this.prisma.trainingContent.findMany({
      orderBy: { createdAt: 'desc' },
      include: { completions: { where: { userId } } },
    });
    return contents.map((c) => {
      const myCompletion = c.completions[0] ?? null;
      const { completions, ...rest } = c;
      return { ...rest, ...this.computeStatus(c, myCompletion?.completedAt ?? null) };
    });
  }

  async getFileUrl(id: string) {
    const content = await this.prisma.trainingContent.findUnique({ where: { id } });
    if (!content) return null;
    if (content.fileUrl.startsWith('http')) return content.fileUrl;
    return this.storage.getSignedUrl(content.fileUrl);
  }

  /** Kullanıcı "Eğitimi Tamamladım" butonuna basınca çağrılır. */
  async markCompleted(trainingId: string, userId: string) {
    await this.prisma.trainingCompletion.upsert({
      where: { trainingId_userId: { trainingId, userId } },
      create: { trainingId, userId },
      update: {},
    });
    return { success: true };
  }

  /**
   * Admin panelinde "kim izledi kim izlemedi" görünümü — tüm aktif
   * bayileri, bu eğitim için tamamlama kaydıyla (varsa) birlikte döner.
   * Kaydı olmayan bayiler, deadline'a göre "PENDING" ya da "EXPIRED"
   * olarak hesaplanır.
   */
  async getCompletionsForAdmin(trainingId: string) {
    const training = await this.prisma.trainingContent.findUnique({ where: { id: trainingId } });
    if (!training) return null;
    const dealers = await this.prisma.user.findMany({
      where: { role: 'DEALER', status: 'ACTIVE' },
      select: { id: true, firstName: true, lastName: true, company: true },
    });
    const completions = await this.prisma.trainingCompletion.findMany({ where: { trainingId } });
    const completionByUser = new Map<string, Date>(completions.map((c) => [c.userId, c.completedAt]));
    const rows = dealers.map((d) => {
      const completedAt = completionByUser.get(d.id) ?? null;
      return { ...d, ...this.computeStatus(training, completedAt) };
    });
    return { training, rows };
  }

  async createWithFile(
    params: { title: string; description?: string; type: 'VIDEO' | 'DOCUMENT'; category?: string; requiresCompletion?: boolean; deadlineHours?: number },
    file: Express.Multer.File,
  ) {
    const key = await this.storage.upload(file.buffer, file.originalname, file.mimetype, 'training');
    return this.finishCreate(params, key);
  }

  async createWithUrl(params: { title: string; description?: string; type: 'VIDEO' | 'DOCUMENT'; category?: string; url: string; requiresCompletion?: boolean; deadlineHours?: number }) {
    return this.finishCreate(params, params.url);
  }

  private async finishCreate(
    params: { title: string; description?: string; type: 'VIDEO' | 'DOCUMENT'; category?: string; requiresCompletion?: boolean; deadlineHours?: number },
    fileUrl: string,
  ) {
    const content = await this.prisma.trainingContent.create({
      data: {
        title: params.title,
        description: params.description,
        type: params.type,
        category: params.category,
        fileUrl,
        requiresCompletion: params.requiresCompletion ?? false,
        deadlineHours: params.deadlineHours ?? 24,
      },
    });

    const dealers = await this.prisma.user.findMany({ where: { role: 'DEALER', status: 'ACTIVE' }, select: { id: true } });
    await Promise.all(
      dealers.map((d) =>
        this.notifications.notifyUser(
          d.id,
          'new_training_content',
          'Yeni Eğitim İçeriği',
          `"${params.title}" eklendi — Eğitim Merkezi'nde inceleyebilirsiniz.`,
        ),
      ),
    );

    return content;
  }

  async remove(id: string) {
    await this.prisma.trainingContent.delete({ where: { id } });
    return { success: true };
  }

  /** Admin, video/dosyanın kendisine dokunmadan başlık/açıklama/kategoriyi düzenler. */
  async update(id: string, data: Partial<{ title: string; description: string; category: string }>) {
    return this.prisma.trainingContent.update({ where: { id }, data });
  }

  // ================= AI SINAV / SERTİFİKASYON MOTORU =================
  // Kullanıcı isteği: "AI Sınav/Sertifikasyon Motoru" — eğitim içeriğini
  // "izledi" işaretlemek yerine, gerçekten öğrenip öğrenmediğini AI'nin
  // ürettiği kısa bir sınavla ölçer. Sorular İÇERİK BAŞINA BİR KEZ
  // üretilip saklanır (her kullanıcı için tekrar tekrar AI çağrısı
  // yapmak hem maliyetli hem tutarsız olurdu).
  private static readonly PASS_SCORE_PERCENT = 70;

  async getOrGenerateQuiz(trainingId: string): Promise<Array<{ question: string; options: string[] }>> {
    const training = await this.prisma.trainingContent.findUnique({ where: { id: trainingId } });
    if (!training) throw new Error('Eğitim içeriği bulunamadı.');

    let questions = training.quizQuestions as
      | Array<{ question: string; options: string[]; correctIndex: number }>
      | null;

    if (!questions || !Array.isArray(questions) || questions.length === 0) {
      questions = await this.generateQuizQuestions(training.title, training.description ?? '');
      await this.prisma.trainingContent.update({ where: { id: trainingId }, data: { quizQuestions: questions } });
    }

    // Doğru cevabı (correctIndex) istemciye GÖNDERMİYORUZ — kopya çekmeyi
    // önlemek için, cevaplar sadece sunucu tarafında (submitQuiz) kontrol
    // ediliyor.
    return questions.map((q) => ({ question: q.question, options: q.options }));
  }

  private async generateQuizQuestions(
    title: string,
    description: string,
  ): Promise<Array<{ question: string; options: string[]; correctIndex: number }>> {
    const systemPrompt = `Sen bir güvenlik sistemleri eğitim içeriğinden sınav sorusu üreten bir asistansın.
Verilen eğitim başlığı ve açıklamasına dayanarak, konuyla İLGİLİ, gerçekten anlaşılıp
anlaşılmadığını ölçen 5 adet çoktan seçmeli soru üret. SADECE aşağıdaki formatta geçerli bir
JSON dizisi döndür — başka HİÇBİR metin, açıklama ya da markdown kod bloğu ekleme:

[{"question": "...", "options": ["...", "...", "...", "..."], "correctIndex": 0}, ...]

Kurallar:
- Her soru için TAM 4 şık olmalı, correctIndex 0-3 arası olmalı.
- Sorular Türkçe, net ve teknik olarak doğru olmalı.
- Eğitim içeriği hakkında yeterli detay yoksa, genel güvenlik sistemleri bilgisi bazlı
  makul sorular üret (boş bırakma).`;

    const result = await this.aiProvider.complete(
      [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: `Başlık: ${title}\nAçıklama: ${description}` },
      ],
      { maxTokens: 1200, temperature: 0.4 },
    );

    try {
      const cleaned = result.text.replace(/```json\s*|```\s*/g, '').trim();
      const parsed = JSON.parse(cleaned);
      if (Array.isArray(parsed) && parsed.length > 0) return parsed;
    } catch {
      // AI çıktısı JSON değilse aşağıdaki yedek soruya düşülür.
    }
    // AI ayrıştırma başarısız olursa sınav TAMAMEN kaybolmasın diye
    // en azından tek bir genel soru ile devam edilir.
    return [
      {
        question: `"${title}" eğitimini tamamladınız mı?`,
        options: ['Evet, tamamladım', 'Hayır', 'Kısmen', 'Emin değilim'],
        correctIndex: 0,
      },
    ];
  }

  /** Kullanıcının verdiği cevapları puanlar, %70 ve üzeri "geçti" sayılır. */
  async submitQuiz(trainingId: string, userId: string, answers: number[]) {
    const training = await this.prisma.trainingContent.findUnique({ where: { id: trainingId } });
    if (!training) throw new Error('Eğitim içeriği bulunamadı.');
    const questions = (training.quizQuestions as Array<{ correctIndex: number }> | null) ?? [];

    let correct = 0;
    questions.forEach((q, i) => {
      if (answers[i] === q.correctIndex) correct++;
    });
    const score = questions.length > 0 ? Math.round((correct / questions.length) * 100) : 0;
    const passed = score >= TrainingService.PASS_SCORE_PERCENT;

    await this.prisma.trainingQuizAttempt.create({
      data: { trainingId, userId, score, passed },
    });

    // Sınavı geçen otomatik olarak "tamamladım" da işaretlenir — ayrıca
    // butona basmasına gerek kalmaz.
    if (passed) {
      await this.markCompleted(trainingId, userId);
    }

    return { score, passed, correctCount: correct, totalQuestions: questions.length };
  }

  /** Bir kullanıcının bu eğitim için EN İYİ sınav sonucunu döner (varsa). */
  async getMyBestQuizAttempt(trainingId: string, userId: string) {
    return this.prisma.trainingQuizAttempt.findFirst({
      where: { trainingId, userId },
      orderBy: { score: 'desc' },
    });
  }
}
