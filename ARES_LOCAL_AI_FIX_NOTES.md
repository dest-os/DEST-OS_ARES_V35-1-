# ARES yerel AI düzeltme notları

Bu paket, yerel model indirme/yükleme ve sağlayıcı yönlendirmesi için hedefli düzeltmeler içerir.

- Android cihazda bellek yükünü azaltmak için resmi `ggml-org/Qwen3-0.6B-GGUF` deposundaki `Qwen3-0.6B-Q4_0.gguf` kullanılır (yaklaşık 429 MB).
- Bağlam ve üretim uzunluğu 256 token seviyesine indirildi.
- Model yükleme tamamlandıktan sonra native katmanın gerçekten `isModelLoaded == true` bildirdiği doğrulanır.
- İndirme tamamlandıktan sonraki yükleme aşaması ayrı gösterilir; indirme yüzdesinin %100'de takılı görünmesi önlenir.
- Yükleme hatası artık genel durum yenilemesi tarafından ezilmez; ekranda asıl hata korunur.
- Gömülü model sağlayıcısının adı eski 1.7B sürümünden yeni model adına güncellenir.
- Gömülü AI etkin olduğunda varsayılan `localhost:11434` Ollama kaydı kapatılır; kullanıcı isterse ayarlardan yeniden etkinleştirebilir.

Not: Bu çalışma ortamında Flutter/Dart SDK bulunmadığından Android APK derlemesi ve gerçek cihaz testi burada çalıştırılamadı. Kod değişiklikleri kaynak düzeyinde kontrol edildi; cihazda başarılı sayılması için APK üzerinde model yükleme ve kısa Türkçe soru testi gerekir.
