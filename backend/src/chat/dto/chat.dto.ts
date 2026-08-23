import { IsOptional, IsString } from 'class-validator';

export class SendMessageDto {
  @IsString()
  content: string;

  @IsOptional()
  @IsString()
  replyToId?: string;
}

export class StartDirectDto {
  @IsString()
  otherUserId: string;
}
