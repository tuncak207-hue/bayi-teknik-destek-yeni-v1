# Manus AI entegrasyonu

Backend, mevcut `AIProvider` arayüzü üzerinden Manus API v2 ajan görevlerini kullanabilir.

## Etkinleştirme

`backend/.env` dosyasına aşağıdaki değerleri ekleyin:

```env
AI_PROVIDER="manus"
MANUS_API_KEY="your-manus-api-key"
MANUS_API_BASE_URL="https://api.manus.ai"
MANUS_AGENT_PROFILE="standard"
MANUS_LOCALE="tr"
MANUS_TIMEOUT_MS="120000"
MANUS_POLL_INTERVAL_MS="2000"
```

`MANUS_API_KEY` yalnızca backend ortamında tutulmalıdır. Mobil veya admin uygulamasına eklenmemelidir.

## Çalışma şekli

`ManusProvider`, teknik destek servisinin oluşturduğu sistem ve kullanıcı mesajlarını tek bir Manus görev istemine dönüştürür. Önce `POST /v2/task.create` ile özel bir görev oluşturulur. Ardından `task.detail` ile görev durumu takip edilir. Görev `stopped` olduğunda `task.listMessages` çağrılır ve son asistan mesajı mevcut AI cevap akışına döndürülür.

`waiting` durumu bu ilk entegrasyonda desteklenmez; Manus’un kullanıcı onayı veya ek giriş beklediği görevler hata olarak sonlandırılır. Görsel içerikli sorular için mevcut Anthropic, Groq veya Ollama sağlayıcılarından biri kullanılmalıdır; Manus sağlayıcısı şu anda yalnızca metin mesajlarını destekler.

## Sağlayıcı seçimi

`AI_PROVIDER` değerleri `anthropic`, `groq`, `ollama` ve `manus` olabilir. Varsayılan değer `anthropic` olarak kalır.
