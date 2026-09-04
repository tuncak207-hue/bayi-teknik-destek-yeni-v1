import { IsOptional, IsString } from 'class-validator';

export class UploadDocumentDto {
  @IsString()
  brand: string;

  @IsString()
  model: string;

  @IsString()
  title: string;

  @IsString()
  version: string;

  @IsOptional()
  @IsString()
  documentId?: string; // Aynı doküman için yeni versiyon yüklenirken doldurulur

  // Kullanıcı isteği (Manus önerisi): "Datasheet-First RAG" — form-data
  // ile string olarak gelir ("true"/"false"), servis katmanında boolean'a
  // çevrilir.
  @IsOptional()
  @IsString()
  isDatasheet?: string;
}
