import { IsDateString, IsEnum, IsOptional, IsString } from 'class-validator';

export class CreateAppointmentDto {
  @IsEnum(['ON_SITE', 'REMOTE'])
  type: 'ON_SITE' | 'REMOTE';

  @IsString()
  subject: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsString()
  province?: string;

  @IsOptional()
  @IsString()
  district?: string;

  @IsDateString()
  preferredStart: string;

  @IsOptional()
  @IsDateString()
  preferredEnd?: string;
}

export class UpdateAppointmentStatusDto {
  @IsEnum(['CONFIRMED', 'CANCELLED', 'COMPLETED'])
  status: 'CONFIRMED' | 'CANCELLED' | 'COMPLETED';

  @IsOptional()
  @IsString()
  adminNote?: string;
}
