-- pgvector eklentisini aktif et ve embedding kolonu için index oluştur.
-- Bu dosya `prisma migrate dev` sonrası oluşan migration klasörüne
-- elle eklenmeli veya aşağıdaki gibi ayrı bir "migration.sql" olarak
-- `prisma db execute --file prisma/manual/001_pgvector.sql` ile çalıştırılmalı.

CREATE EXTENSION IF NOT EXISTS vector;

-- Prisma "Unsupported(vector(1536))" tipini şema seviyesinde temsil eder
-- ama index'i otomatik oluşturmaz. IVFFlat cosine-distance index:
CREATE INDEX IF NOT EXISTS document_chunks_embedding_idx
  ON document_chunks
  USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);

-- Not: "lists" değeri veri büyüdükçe ayarlanmalı (kabaca sqrt(satır sayısı)).
