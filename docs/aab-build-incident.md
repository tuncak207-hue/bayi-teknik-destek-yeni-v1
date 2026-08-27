# İlk production AAB build bulgusu

Tarih: 2026-08-28

GitHub Actions run 33121507622, `Materialize production-only files` adımında durdu. Hata: `base64: invalid input`. Decode sırası nedeniyle ilk şüpheli `FIREBASE_GOOGLE_SERVICES_JSON_B64` secret’ıdır. `KEY_PROPERTIES_B64` ve `KEYSTORE_B64` decode aşamasına ulaşılmadı. Build APK/AAB üretme aşamasına geçmedi.

Planlanan düzeltme: `FIREBASE_GOOGLE_SERVICES_JSON_B64` secret’ını yalnızca `mobile/android/app/google-services.json` dosyasından PowerShell `[Convert]::ToBase64String([IO.File]::ReadAllBytes(...)) | Set-Clipboard` komutuyla yeniden oluşturmak; servis hesabı `firebase-adminsdk` JSON’u kullanılmayacak.
