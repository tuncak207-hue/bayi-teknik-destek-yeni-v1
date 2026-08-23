import { IsOptional, IsString } from 'class-validator';

export class AskAiDto {
  @IsString()
  question: string;

  @IsOptional()
  @IsString()
  conversationId?: string; // yoksa yeni AI konuşması oluşturulur

  @IsOptional()
  @IsString()
  brand?: string;

  @IsOptional()
  @IsString()
  model?: string;
}
