import { IsBoolean, IsEmail, IsString, MinLength } from 'class-validator';

export class RegisterDto {
  @IsString()
  firstName: string;

  @IsString()
  lastName: string;

  @IsString()
  company: string;

  @IsString()
  phone: string;

  @IsEmail()
  email: string;

  @IsString()
  @MinLength(8, { message: 'Şifre en az 8 karakter olmalı.' })
  password: string;

  @IsBoolean({ message: 'KVKK Aydınlatma Metni onayı zorunludur.' })
  acceptedKvkk: boolean;

  @IsBoolean({ message: 'Gizlilik Politikası onayı zorunludur.' })
  acceptedPrivacyPolicy: boolean;
}
