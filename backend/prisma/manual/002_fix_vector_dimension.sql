-- voyage-3 embedding modeli 1024 boyutlu vektör üretir, ama tablo başlangıçta
-- 1536 boyutlu (OpenAI text-embedding-3-small varsayımıyla) oluşturulmuştu.
-- Bu script sütunu doğru boyuta çevirir. Mevcut (varsa) satırları siler çünkü
-- farklı boyuttaki eski vektörler yeni boyutla uyumsuzdur.

DELETE FROM document_chunks;
ALTER TABLE document_chunks ALTER COLUMN embedding TYPE vector(1024);
