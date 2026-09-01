import { Body, Controller, Post, Req, Res, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Throttle } from '@nestjs/throttler';
import type { Request, Response } from 'express';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { SocialAuthDto } from './dto/social-auth.dto';

const ACCESS_COOKIE = 'admin_access_token';
const REFRESH_COOKIE = 'admin_refresh_token';

type TokenPayload = { sub: string; email?: string; role?: string };

function readCookie(request: Request, name: string) {
  const cookieHeader = request.headers.cookie;
  if (!cookieHeader) return null;
  const cookie = cookieHeader
    .split(';')
    .map((part) => part.trim())
    .find((part) => part.startsWith(`${name}=`));
  return cookie ? decodeURIComponent(cookie.slice(name.length + 1)) : null;
}

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService, private jwt: JwtService) {}

  // GÜVENLİK DÜZELTMESİ: Bu uç nokta internete açık ve kimlik doğrulama
  // gerektirmiyor. Genel throttler (dakikada 100 istek) botların art arda
  // sahte bayi kaydı oluşturmasını engellemeye yetmiyordu — admin panelde
  // "Test Firma", "testuser_unique_123@example.com" gibi otomatik üretilmiş
  // hesaplar birikiyordu. Bu uç noktaya özel, çok daha sıkı bir sınır
  // (aynı IP'den saatte en fazla 5 kayıt denemesi) ekliyoruz.
  @Throttle({ default: { limit: 5, ttl: 3600000 } })
  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Throttle({ default: { limit: 10, ttl: 60000 } })
  @Post('login')
  async login(@Body() dto: LoginDto, @Res({ passthrough: true }) response: Response) {
    const tokens = await this.authService.login(dto);
    this.setAuthCookies(response, tokens);
    return tokens;
  }

  @Post('google')
  googleLogin(@Body() dto: SocialAuthDto) {
    return this.authService.googleLogin(dto);
  }

  @Post('phone')
  phoneLogin(@Body() dto: SocialAuthDto) {
    return this.authService.phoneLogin(dto);
  }

  @Post('refresh')
  async refresh(@Req() request: Request, @Res({ passthrough: true }) response: Response) {
    const refreshToken = readCookie(request, REFRESH_COOKIE) || this.readBearerToken(request);
    if (!refreshToken) throw new UnauthorizedException('Yenileme oturumu bulunamadı.');

    let payload: TokenPayload;
    try {
      payload = this.jwt.verify<TokenPayload>(refreshToken);
    } catch {
      throw new UnauthorizedException('Yenileme oturumu geçersiz veya süresi dolmuş.');
    }

    const tokens = await this.authService.refresh(payload.sub);
    this.setAuthCookies(response, tokens);
    return tokens;
  }

  @Post('logout')
  logout(@Res({ passthrough: true }) response: Response) {
    const options = this.cookieOptions();
    response.clearCookie(ACCESS_COOKIE, options);
    response.clearCookie(REFRESH_COOKIE, options);
    return { success: true };
  }

  private readBearerToken(request: Request) {
    const header = request.headers.authorization;
    return header?.startsWith('Bearer ') ? header.slice('Bearer '.length) : null;
  }

  private setAuthCookies(response: Response, tokens: { accessToken: string; refreshToken: string }) {
    const options = this.cookieOptions();
    response.cookie(ACCESS_COOKIE, tokens.accessToken, {
      ...options,
      maxAge: 15 * 60 * 1000,
    });
    response.cookie(REFRESH_COOKIE, tokens.refreshToken, {
      ...options,
      maxAge: 30 * 24 * 60 * 60 * 1000,
    });
  }

  private cookieOptions() {
    // ÖNEMLİ DÜZELTME: "girince kendi kendine atıyor" — admin panel ile
    // backend FARKLI alan adlarında (cross-origin) çalıştığında,
    // "sameSite: 'lax'" tarayıcının çerezi bu isteklerde GÖNDERMESİNİ
    // engelliyordu (giriş başarılı oluyordu ama sonraki her istek
    // "giriş yapılmamış" gibi davranıyordu). Cross-origin çerezlerin
    // çalışması için "sameSite: 'none'" + "secure: true" gerekiyor.
    const isProduction = process.env.NODE_ENV === 'production';
    return {
      httpOnly: true,
      secure: isProduction,
      sameSite: (isProduction ? 'none' : 'lax') as 'none' | 'lax',
      path: '/',
    };
  }
}
