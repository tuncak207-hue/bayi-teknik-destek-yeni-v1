import { IsOptional, IsString, MinLength } from 'class-validator';

export class ChangePasswordDto {
  @IsString()
  currentPassword: string;

  @IsString()
  @MinLength(8, { message: 'Yeni şifre en az 8 karakter olmalı.' })
  newPassword: string;
}

export class DeleteAccountDto {
  /** Google/telefon ile giriş yapan kullanıcıların yerel şifresi yoktur. */
  @IsOptional()
  @IsString()
  password?: string;
}
