-- Kullanıcı isteği: "slayt video olarak da dönebiliyor mu" — slaytların
-- görsel mi video mu olduğunu ayırt etmek için eklendi. Mevcut tüm
-- slaytlar geriye dönük uyumluluk için otomatik olarak "IMAGE" kalır.
ALTER TABLE "slides" ADD COLUMN "mediaType" TEXT NOT NULL DEFAULT 'IMAGE';
