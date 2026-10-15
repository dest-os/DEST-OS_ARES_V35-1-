# DEST-OS ARES V35 — Yerel yapay zekâ (Qwen3-0.6B Q4_0) düzeltmeleri

## V34'te bulunan bozukluklar
- lib/main.dart başka bir projenin "BAŞLAT" ekranı olmuştu ve olmayan secim_ekrani.dart'ı içe aktarıyordu (derlenmezdi).
- pubspec.yaml başka projeye aitti (ares_asistan); path_provider, path, llama_flutter_android ve assets/images eksikti.
- lib/infrastructure/ai/ares_servis.dart gerçek olmayan (sahte, bekleyip hazır cevap veren) bir yerel AI taklidiydi; silindi.
→ main.dart ve pubspec.yaml, ARES ofis sürümündeki doğru haline döndürüldü.

## Yerel yapay zekâ için yapılanlar
1. Qwen3 sohbet biçimi (ChatML) ve "düşünme" kapatma eklendi. Önceden ham metin veriliyordu; 0.6B model anlamsız/boş cevap üretirdi.
2. Bağlam 256 → 2048 token (1024 ve 512'ye otomatik geri düşme). 256, uygulamanın istemlerine sığmıyordu.
3. Model cihazdaysa uygulama açılınca arka planda otomatik yüklenir; sohbette de gerekirse otomatik yüklenir.
4. Eşzamanlı yükleme/üretim tek sıraya alındı; üretimde 90 sn hareketsizlik zaman aşımı.
5. İndirme: 60 sn veri gelmezse kesilir, "indirilen / toplam MB" gösterilir, kullanıcı-ajanı başlığı eklendi.
6. Ayarlar > Genel AI Ayarları kartı: "İndir ve yükle", "Modeli yükle", "Hızlı test" (süre ve tahmini hız gösterir), "Durumu yenile".
7. Cihaz içi küçük model sıradaki ilk yapay zekâysa CEO incelemesi atlanır ve istemler kısaltılır.
8. GPU tespiti (detectGpu) kaldırıldı: CPU ile çalışır, olası yerel çökme riski azaltıldı.

## Cihazda doğrulama (sırayla)
1. Ayarlar > Genel AI Ayarları > "İndir ve yükle" (Wi-Fi, ≈430 MB).
2. "Hızlı test": kısa Türkçe bir cevap ve token/sn görünmeli.
3. Sohbette "merhaba" yazın: cevap Qwen3-0.6B'den gelmeli.
4. Uygulamayı kapatıp açın: model otomatik yüklenmeli (ana ekran bildirimlerinde "Yerel yapay zekâ hazır").

## Bilinen sınırlar
- llama_flutter_android eklentisinin kaynağı bu ortamda okunamadı; eklenti çağrıları (loadModel, generate, stop) önceki çalışan sürümle aynı bırakıldı.
- "Hızlı test" çıktısı bozuksa (özel etiketler görünüyorsa) eklenti istemdeki özel jetonları ayrıştırmıyor demektir; bir sonraki adım düzeltmesi buna göre yapılır.
- 0.6B model küçüktür: kısa/basit işlerde iyi, uzun ve karmaşık işlerde hata yapabilir. Çok adımlı işler (kod üretimi vb.) için daha büyük bir model veya bulut sağlayıcı gerekir.
- Derleme hata verirse GitHub Actions > derleme-raporu dosyasını gönderin.
