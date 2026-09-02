-- Kullanıcı isteği: "Dijital Cihaz Pasaportu" — devreye alınan her cihaza
-- benzersiz bir QR kod atanır, bakım/arıza kayıtları bu cihaza bağlanabilir.

-- AlterTable: CommissioningReport'a seri no + QR kod ekle
ALTER TABLE "commissioning_reports" ADD COLUMN "serialNumber" TEXT;
ALTER TABLE "commissioning_reports" ADD COLUMN "deviceQrCode" TEXT;

-- Var olan kayıtlara benzersiz bir QR kod ata (PostgreSQL'in kendi UUID
-- üreticisiyle) — sonra NOT NULL + UNIQUE kısıtlaması eklenebilsin diye.
UPDATE "commissioning_reports" SET "deviceQrCode" = gen_random_uuid()::text WHERE "deviceQrCode" IS NULL;

ALTER TABLE "commissioning_reports" ALTER COLUMN "deviceQrCode" SET NOT NULL;
CREATE UNIQUE INDEX "commissioning_reports_deviceQrCode_key" ON "commissioning_reports"("deviceQrCode");

-- AlterTable: MaintenanceRecord'a opsiyonel cihaz bağlantısı ekle
ALTER TABLE "maintenance_records" ADD COLUMN "commissioningReportId" TEXT;
ALTER TABLE "maintenance_records" ADD CONSTRAINT "maintenance_records_commissioningReportId_fkey"
  FOREIGN KEY ("commissioningReportId") REFERENCES "commissioning_reports"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AlterTable: SupportTicket'a opsiyonel cihaz bağlantısı ekle
ALTER TABLE "support_tickets" ADD COLUMN "commissioningReportId" TEXT;
ALTER TABLE "support_tickets" ADD CONSTRAINT "support_tickets_commissioningReportId_fkey"
  FOREIGN KEY ("commissioningReportId") REFERENCES "commissioning_reports"("id") ON DELETE SET NULL ON UPDATE CASCADE;
