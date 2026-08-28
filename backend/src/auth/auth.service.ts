import {
  Injectable,
  ConflictException,
  BadRequestException,
  UnauthorizedException,
  ForbiddenException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { OAuth2Client } from 'google-auth-library';
import { PrismaService } from '../common/prisma/prisma.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';

@Injectable()
export class AuthService {
  private googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);
  private firebaseAdmin: any;

  constructor(private prisma: PrismaService, private jwt: JwtService) {}

  private getFirebaseAdmin() {
    if (this.firebaseAdmin) return this.firebaseAdmin;
    const config = process.env.FIREBASE_CONFIG;
    if (!config) return null;
    // NotificationsService de aynı desende Firebase'i başlatıyor; firebase-admin
    // global bir kayıt tuttuğu için `apps.length` kontrolü iki yerden de
    // çağrılsa çakışma olmaz.
    const firebaseAdmin = require('firebase-admin');
    if (!firebaseAdmin.apps.length) {
      firebaseAdmin.initializeApp({ credential: firebaseAdmin.credential.cert(JSON.parse(config)) });
    }
    this.firebaseAdmin = firebaseAdmin;
    return firebaseAdmin;
  }

  async register(dto: RegisterDto) {
    if (dto.acceptedKvkk !== true || dto.acceptedPrivacyPolicy !== true) {
      throw new BadRequestException('KVKK Aydınlatma Metni ve Gizlilik Politikası onayı zorunludur.');
    }

    const existing = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (existing) {
      throw new ConflictException('Bu e-posta ile kayıtlı bir hesap zaten var.');
    }

    const passwordHash = await bcrypt.hash(dto.password, 12);

    const user = await this.prisma.user.create({
      data: {
        firstName: dto.firstName,
        lastName: dto.lastName,
        company: dto.company,
        phone: dto.phone,
        email: dto.email,
        passwordHash,
        status: 'PENDING', // admin onayı bekliyor
        kvkkAcceptedAt: new Date(),
        kvkkConsentVersion: '2026-08-28',
        privacyAcceptedAt: new Date(),
        privacyConsentVersion: '2026-08-28',
      },
    });

    return {
      message: 'Hesabınız admin onayı bekliyor.',
      userId: user.id,
    };
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (!user) throw new UnauthorizedException('E-posta veya şifre hatalı.');

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) throw new UnauthorizedException('E-posta veya şifre hatalı.');

    if (user.status === 'PENDING') {
      throw new ForbiddenException('Hesabınız admin onayı bekliyor.');
    }
    if (user.status === 'SUSPENDED') {
      throw new ForbiddenException('Hesabınız pasifleştirilmiş. Lütfen admin ile iletişime geçin.');
    }
    if (user.status === 'DELETED') {
      throw new ForbiddenException('Bu hesap silinmiş.');
    }

    return this.issueTokens(user.id, user.email, user.role);
  }

  async refresh(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user || user.status !== 'ACTIVE') throw new UnauthorizedException();
    return this.issueTokens(user.id, user.email, user.role);
  }

  private issueTokens(sub: string, email: string, role: string) {
    const payload = { sub, email, role };
    const accessToken = this.jwt.sign(payload, { expiresIn: '15m' });
    const refreshToken = this.jwt.sign(payload, { expiresIn: '30d' });
    // Pasif bayi tespiti için — her başarılı girişte son giriş zamanını
    // güncelliyoruz. Girişi bekletmemek için sonucu beklemeden (fire-and-forget)
    // çalıştırıyoruz.
    void this.prisma.user.update({ where: { id: sub }, data: { lastLoginAt: new Date() } }).catch(() => {});
    return { accessToken, refreshToken };
  }

  /**
   * Google ile giriş/kayıt. Mobil taraf `google_sign_in` ile aldığı ID Token'ı
   * gönderir, biz Google'ın kütüphanesiyle doğrularız — şifre hiç devreye girmez.
   *
   * NOT (MVP basitleştirmesi): Google hesabı e-postayla eşleşen bir kullanıcı
   * yoksa otomatik yeni bir kayıt oluşturuyoruz (firma/telefon bilgisi olmadan,
   * "Belirtilmedi" yer tutucusuyla, admin onayı bekleyen PENDING durumda).
   * Gerçek kullanımda bayi, giriş sonrası "Profili Düzenle" ekranından firma ve
   * telefon bilgisini tamamlamalı — bu akışa ayrı bir "bilgileri tamamlayın"
   * ekranı eklemek daha iyi bir deneyim olur, burada kapsam dışı bırakıldı.
   */
  async googleLogin(idToken: string) {
    if (!process.env.GOOGLE_CLIENT_ID) {
      throw new UnauthorizedException('Google girişi bu sunucuda yapılandırılmamış (GOOGLE_CLIENT_ID eksik).');
    }

    let payload;
    try {
      const ticket = await this.googleClient.verifyIdToken({
        idToken,
        audience: process.env.GOOGLE_CLIENT_ID,
      });
      payload = ticket.getPayload();
    } catch {
      throw new UnauthorizedException('Google token doğrulanamadı veya süresi dolmuş.');
    }
    if (!payload?.email) throw new UnauthorizedException('Google token doğrulanamadı.');

    let user = await this.prisma.user.findUnique({ where: { email: payload.email } });
    if (!user) {
      const randomPassword = await bcrypt.hash(`google-${payload.sub}-${Date.now()}`, 12);
      user = await this.prisma.user.create({
        data: {
          firstName: payload.given_name || 'Bayi',
          lastName: payload.family_name || '',
          company: 'Belirtilmedi',
          phone: '',
          email: payload.email,
          passwordHash: randomPassword,
          avatarUrl: payload.picture,
          status: 'PENDING',
        },
      });
      return { message: 'Hesabınız Google ile oluşturuldu, admin onayı bekliyor.', userId: user.id, isNewUser: true };
    }

    this.assertLoginAllowed(user);
    return { ...this.issueTokens(user.id, user.email, user.role), isNewUser: false };
  }

  /**
   * Telefon numarasıyla giriş/kayıt (Firebase Phone Authentication).
   * Mobil taraf Firebase'in kendi SMS doğrulama akışını kullanır, bize sadece
   * doğrulanmış bir ID Token gönderir. Aynı MVP basitleştirmesi burada da
   * geçerli — yeni kullanıcı otomatik, eksik bilgilerle, PENDING oluşturulur.
   */
  async phoneLogin(idToken: string) {
    const admin = this.getFirebaseAdmin();
    if (!admin) throw new UnauthorizedException('Telefon girişi bu sunucuda yapılandırılmamış (FIREBASE_CONFIG eksik).');

    const decoded = await admin.auth().verifyIdToken(idToken);
    const phoneNumber = decoded.phone_number;
    if (!phoneNumber) throw new UnauthorizedException('Token içinde telefon numarası bulunamadı.');

    let user = await this.prisma.user.findFirst({ where: { phone: phoneNumber } });
    if (!user) {
      const randomPassword = await bcrypt.hash(`phone-${decoded.uid}-${Date.now()}`, 12);
      // E-posta şemada zorunlu/tekil olduğu için telefon bazlı bir yer tutucu üretiyoruz.
      const placeholderEmail = `phone-${phoneNumber.replace(/[^\d]/g, '')}@placeholder.local`;
      user = await this.prisma.user.create({
        data: {
          firstName: 'Bayi',
          lastName: '',
          company: 'Belirtilmedi',
          phone: phoneNumber,
          email: placeholderEmail,
          passwordHash: randomPassword,
          status: 'PENDING',
        },
      });
      return { message: 'Hesabınız telefon numaranızla oluşturuldu, admin onayı bekliyor.', userId: user.id, isNewUser: true };
    }

    this.assertLoginAllowed(user);
    return { ...this.issueTokens(user.id, user.email, user.role), isNewUser: false };
  }

  private assertLoginAllowed(user: { status: string }) {
    if (user.status === 'PENDING') throw new ForbiddenException('Hesabınız admin onayı bekliyor.');
    if (user.status === 'SUSPENDED') throw new ForbiddenException('Hesabınız pasifleştirilmiş. Lütfen admin ile iletişime geçin.');
    if (user.status === 'DELETED') throw new ForbiddenException('Bu hesap silinmiş.');
  }
}
