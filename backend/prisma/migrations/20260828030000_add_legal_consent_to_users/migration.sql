-- Track the legal document versions accepted during account registration.
ALTER TABLE "users"
  ADD COLUMN "kvkkAcceptedAt" TIMESTAMP(3),
  ADD COLUMN "kvkkConsentVersion" TEXT,
  ADD COLUMN "privacyAcceptedAt" TIMESTAMP(3),
  ADD COLUMN "privacyConsentVersion" TEXT;
