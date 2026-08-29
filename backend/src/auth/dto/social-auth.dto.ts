import { IsBoolean, IsString } from 'class-validator';

export class SocialAuthDto {
  @IsString()
  idToken: string;

  @IsBoolean({ message: 'KVKK Aydınlatma Metni onayı zorunludur.' })
  acceptedKvkk: boolean;

  @IsBoolean({ message: 'Gizlilik Politikası onayı zorunludur.' })
  acceptedPrivacyPolicy: boolean;
}
