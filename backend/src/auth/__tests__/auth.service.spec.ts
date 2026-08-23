import { Test } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { ConflictException, UnauthorizedException, ForbiddenException } from '@nestjs/common';
import { AuthService } from '../auth.service';
import { PrismaService } from '../../common/prisma/prisma.service';

describe('AuthService', () => {
  let service: AuthService;
  let prisma: { user: Record<string, jest.Mock> };
  let jwt: JwtService;

  beforeEach(async () => {
    prisma = {
      user: {
        findUnique: jest.fn(),
        create: jest.fn(),
      },
    };

    const moduleRef = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: prisma },
        { provide: JwtService, useValue: { sign: jest.fn().mockReturnValue('signed-token') } },
      ],
    }).compile();

    service = moduleRef.get(AuthService);
    jwt = moduleRef.get(JwtService);
  });

  describe('register', () => {
    it('yeni bayiyi PENDING durumunda oluşturur ve onay bekleme mesajı döner', async () => {
      prisma.user.findUnique.mockResolvedValue(null);
      prisma.user.create.mockResolvedValue({ id: 'user-1' });

      const result = await service.register({
        firstName: 'Ali',
        lastName: 'Yılmaz',
        company: 'ABC Güvenlik',
        phone: '5551234567',
        email: 'ali@abc.com',
        password: 'Sifre1234',
      });

      expect(prisma.user.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ email: 'ali@abc.com', status: 'PENDING' }),
        }),
      );
      expect(result.message).toBe('Hesabınız admin onayı bekliyor.');
    });

    it('aynı e-posta ile kayıtlı kullanıcı varsa ConflictException fırlatır', async () => {
      prisma.user.findUnique.mockResolvedValue({ id: 'existing' });

      await expect(
        service.register({
          firstName: 'Ali',
          lastName: 'Yılmaz',
          company: 'ABC',
          phone: '5551234567',
          email: 'ali@abc.com',
          password: 'Sifre1234',
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('login', () => {
    it('PENDING durumundaki bayi giriş yapamaz', async () => {
      const passwordHash = await bcrypt.hash('Sifre1234', 4);
      prisma.user.findUnique.mockResolvedValue({
        id: 'user-1',
        passwordHash,
        status: 'PENDING',
        role: 'DEALER',
        email: 'ali@abc.com',
      });

      await expect(service.login({ email: 'ali@abc.com', password: 'Sifre1234' })).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('SUSPENDED durumundaki bayi giriş yapamaz', async () => {
      const passwordHash = await bcrypt.hash('Sifre1234', 4);
      prisma.user.findUnique.mockResolvedValue({
        id: 'user-1',
        passwordHash,
        status: 'SUSPENDED',
        role: 'DEALER',
        email: 'ali@abc.com',
      });

      await expect(service.login({ email: 'ali@abc.com', password: 'Sifre1234' })).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('yanlış şifrede UnauthorizedException fırlatır', async () => {
      const passwordHash = await bcrypt.hash('DogruSifre', 4);
      prisma.user.findUnique.mockResolvedValue({
        id: 'user-1',
        passwordHash,
        status: 'ACTIVE',
        role: 'DEALER',
        email: 'ali@abc.com',
      });

      await expect(service.login({ email: 'ali@abc.com', password: 'YanlisSifre' })).rejects.toThrow(
        UnauthorizedException,
      );
    });

    it('ACTIVE bayi doğru şifreyle giriş yapınca access/refresh token döner', async () => {
      const passwordHash = await bcrypt.hash('Sifre1234', 4);
      prisma.user.findUnique.mockResolvedValue({
        id: 'user-1',
        passwordHash,
        status: 'ACTIVE',
        role: 'DEALER',
        email: 'ali@abc.com',
      });

      const result = await service.login({ email: 'ali@abc.com', password: 'Sifre1234' });

      expect(result).toEqual({ accessToken: 'signed-token', refreshToken: 'signed-token' });
      expect(jwt.sign).toHaveBeenCalledTimes(2);
    });
  });
});
