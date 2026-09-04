-- Kullanıcı isteği (Manus önerisi): "Datasheet-First RAG" — resmi
-- datasheet/teknik döküman olarak işaretlenen kaynaklar AI cevap
-- üretirken ÖNCELİKLİ olarak aranır.

ALTER TABLE "documents" ADD COLUMN "isDatasheet" BOOLEAN NOT NULL DEFAULT false;
