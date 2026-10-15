# DEST-OS ARES — GitHub yükleme (kısa)

Bu ZIP, GitHub’a **yeni repo** olarak yüklenecek tam Flutter projesidir.

## Ne var?
- Ana ekran: verdiğiniz `ares_ana_ekran.png` + ImageStage hitbox (V33 düzeltmesi korundu)
- Yerel AI: `llama_flutter_android` (ARES Yerel AI / GGUF indirme + yükleme)
- Uzak AI: Groq, OpenRouter, Gemini, OpenAI, Anthropic katalog + API anahtarı
- Dinleyici sohbet, CEO yönlendirme, CIO canlı paneller, ofis hub
- GitHub Actions: APK build workflow

## GitHub’a yükleme
1. GitHub’da boş bir repo oluşturun (ör. `son-grog`)
2. Bu ZIP’i açın
3. Tüm içeriği (klasörün içini) repo köküne yükleyin
4. Actions → **ARES APK Build** → Run workflow
5. Bitince Artifacts’ten APK indirin

## Tablet’te ilk kullanım
1. Ayarlar (CEO masası gözü)
2. **ARES Yerel AI** → modeli indir → yükle (yaklaşık 429 MB, Wi‑Fi önerilir)
3. İsteğe bağlı: Groq/OpenRouter vb. API anahtarı girin, Kaydet ve Test Et
4. Dinleyici → sohbetten komut verin

## Notlar
- Ücretli AI onaysız çağrılmaz
- Yerel model yükleme cihazda RAM ister; hata olursa Ayarlar’daki durum metnini okuyun
- Hitbox koordinatları tasarım referansına göredir; bozmayın
