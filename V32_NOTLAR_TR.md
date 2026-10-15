# DEST-OS ARES V32 — Adım 1 Notları (Senaryo Uyumlu Güncelleme)

Bu sürümde yapılanlar (V31 incelemesindeki eksiklere + ofis senaryosu + ekran görsellerine göre):

1. **Ana ekran (görsel ofis)**  
   `ares_ana_ekran.png` tam ekran arka plan olarak kullanılır. Tasarım değiştirilmez.  
   Görünmez hitbox katmanı:
   - Sol DİNLEYİCİ (üst panel + masa) → ARES Sohbet
   - Merkez CEO masası gözü + üst CEO paneli → Sistem & API Ayarları
   - Alt Çalışan Ajanlar / Arşiv → Eğitim ekranı
   - Sol İletişim → Sohbet
   - Sağ Sistem Durumu → sağlık yenileme
   Küçük hızlı erişim FAB’ları (Mobil / Video / İçerik) sol altta, görseli bozmaz.

2. **Ayarlar ekranı (CEO masası gözü)**  
   Tab’lı yapı: Genel Ayarlar | AI Kataloğu | API Anahtarları | Model Sıralaması | Kullanım & Limitler | Onaylar.  
   AI Kataloğu senaryoya uygun renk kodları:
   - Yeşil = kullanımda / ücretsiz
   - Sarı = sınırlı ücretsiz
   - Kırmızı = ücretli
   - Yerel, Araç, Diğer kategoriler  
   Yerel açık kaynak AI başlangıç için varsayılandır. Ücretli AI kullanıcı onayı olmadan kullanılmaz.

3. **Sohbet ekranı (Dinleyici)**  
   Mesaj gerçekten yapay zekâya gider, cevap görünür, hata Türkçe gösterilir.  
   Benzer arşiv eşleşmesi, referans kullanımı, gizli metin scrubbing korunur.

4. **Eğitim / Arşiv**  
   Kayıtlar "06 Ekim 2026 — konu" başlığıyla, diskte kalıcı, yanında sil simgesi (onaylı),  
   90 günden eskiler için hatırlatma. API anahtarı/parola benzeri metinler kaydedilmeden gizlenir.

5. **Benzer çalışma önerisi**  
   Yeni sohbetin ilk mesajı arşivle eşleşirse "referans olarak kullanılsın mı?" diye sorar;  
   evet denirse yalnızca kısa özet gönderilir (token tasarrufu).

6. **Ajanlar birbirinin çıktısını görür**  
   Her aşamaya önceki dosyalardan kısaltılmış alıntılar eklenir (toplam ~6000 karakter).

7. Kod/içerik üretimi bitince sonuç otomatik arşive yazılır.

8. `allowBackup=false`: API anahtarı bulut yedeğine karışmasın.

## Senaryo hiyerarşisi (korunan)

- Kullanıcı ↔ Dinleyici (sesli/yazılı) ↔ CEO ↔ ekipler (Araştırma / Geliştirme / İçerik / Destek)
- CEO görev dağıtır, en fazla 3 kez düzeltme döngüsü
- CIO: sistem yönetimi, AI altyapısı, güvenlik, veri & entegrasyon, teknik destek, canlı operasyon sütunu
- Kotası dolan ajan → başka ajana devir

## Cihaz

TCL NXTPAPER 14.3 inch, 8+8 RAM, 256 GB, 60 Hz, 2400×1600 — kişisel kullanım, ticari sürüm değil.

## Henüz yapılmayanlar

CEO’nun hata yorumlayıp 3 kez düzeltme talimatı vermesi ve ayrıntılı rapor, tam canlı operasyon panosu (sağ sütun gerçek zamanlı),  
AI Radar (internetten yeni model bulma), sesli komut entegrasyonu, gerçek derleme kontrolü, anahtarın şifreli depoda saklanması.

DİKKAT: Bu sürüm Flutter kurulu olmayan ortamda düzenlendi; derlenmedi ve testler çalıştırılmadı.  
İlk iş GitHub Actions derlemesini çalıştırın; hata çıkarsa günlüğü olduğu gibi iletin.

## Build hata duzeltmeleri (09 Ekim 2026)

GitHub Actions `flutter analyze` hatalarinin bir kismi duzeltildi:
- AresId.generate() eklendi
- AgentProfile status/skills alanlari eklendi
- Task modeli birlestirildi
- Connector / Project / Memory import eksikleri giderildi
- Bozuk Turkce string ve regex satirlari duzeltildi
- const constructor uyumsuzluklari giderildi

Kalan uyarilar olabilir; kritik compile hatalari azaltildi.
Yeniden Actions uzerinden build alin.
