import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';

export interface JwtPayload {
  sub: string;
  email: string;
  role: 'DEALER' | 'ADMIN';
}

function extractAdminCookie(request: { headers?: { cookie?: string } } | undefined) {
  const cookieHeader = request?.headers?.cookie;
  if (!cookieHeader) return null;

  const cookie = cookieHeader
    .split(';')
    .map((part) => part.trim())
    .find((part) => part.startsWith('admin_access_token='));
  return cookie ? decodeURIComponent(cookie.slice('admin_access_token='.length)) : null;
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(config: ConfigService) {
    super({
      jwtFromRequest: (request) =>
        ExtractJwt.fromAuthHeaderAsBearerToken()(request) || extractAdminCookie(request),
      ignoreExpiration: false,
      secretOrKey: config.get<string>('JWT_SECRET'),
    });
  }

  async validate(payload: JwtPayload) {
    return payload;
  }
}
