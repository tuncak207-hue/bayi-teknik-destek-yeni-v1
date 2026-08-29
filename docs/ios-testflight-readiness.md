# iOS / TestFlight Hazırlık Notu

## Hazırlananlar

Flutter iOS projesi iOS 13.0 minimum sürümle yapılandırılmıştır. Bundle identifier mevcut Xcode projesindeki `com.bayiteknikdestek.bayiTeknikDestek` olarak korunmuştur. Eksik CocoaPods `Podfile` eklendi, iOS launcher icon üretimi etkinleştirildi ve macOS runner üzerinde analyze, test ve imzasız release build çalıştıran `iOS CI` workflow’u eklendi.

## Apple tarafında gerekli işlemler

TestFlight için Apple Developer Program üyeliği, App Store Connect’te uygulama kaydı ve Apple imzalama materyalleri gerekir. Apple Developer portalında bundle identifier olarak `com.bayiteknikdestek.bayiTeknikDestek` kaydedilmelidir. Firebase Console’da aynı bundle identifier ile bir iOS uygulaması eklenmeli ve üretilen `GoogleService-Info.plist` dosyası güvenli biçimde `mobile/ios/Runner/GoogleService-Info.plist` konumuna alınmalıdır. Bu dosya repository’ye commit edilmemelidir.

İmzalı TestFlight build’i için Apple Distribution sertifikası, App Store provisioning profile veya App Store Connect API key gerekir. Bunlar GitHub Secrets olarak saklanmalı; sertifika/parola veya private key düz metin olarak commit edilmemelidir. Apple imzalama bilgileri hazır olmadan yalnızca `--no-codesign` doğrulaması yapılabilir; bu dosya TestFlight’a yüklenemez.

## Beklenen GitHub Secret adları

| Secret | İçerik |
|---|---|
| `FIREBASE_GOOGLE_SERVICE_INFO_PLIST_B64` | Firebase `GoogleService-Info.plist` dosyasının Base64 değeri |
| `IOS_CERTIFICATE_P12_B64` | Apple Distribution `.p12` sertifikası Base64 değeri |
| `IOS_CERTIFICATE_PASSWORD` | `.p12` parolası |
| `IOS_PROVISIONING_PROFILE_B64` | App Store provisioning profile Base64 değeri |
| `IOS_KEYCHAIN_PASSWORD` | CI geçici keychain parolası |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect issuer ID |
| `APP_STORE_CONNECT_PRIVATE_KEY_B64` | App Store Connect API private key Base64 değeri |

İmzalı release için sertifika/provisioning yaklaşımı veya App Store Connect API key yaklaşımından biri seçilmelidir; iki yöntemin aynı anda zorunlu tutulması gerekmez.

## Doğrulama sınırı

Linux ortamında Xcode ve Apple code signing bulunmadığından burada imzalı IPA üretilemez. Repository’ye eklenen `iOS CI` workflow’u macOS GitHub runner üzerinde Flutter analyze, test, CocoaPods kurulumu ve `flutter build ios --release --no-codesign` adımlarını doğrular. TestFlight dağıtımı, Apple hesap erişimi ve imzalama secrets’ları hazırlandıktan sonra ayrı bir signed release workflow’u ile yapılmalıdır.
