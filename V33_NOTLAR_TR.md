# DEST-OS ARES V33 — Notlar

Temel: derlenen "son-grog" sürümü (Android ayarları, AGP 9 / Gradle 9.1 olduğu gibi korundu).

## Dokunma katmanı kaymasının nedeni ve çözümü
Görsel BoxFit.cover ile ekrana yayılıyor, dokunma alanları ise ekran yüzdesiyle yerleştiriliyordu.
Tablet ekranı görselle aynı oranda olmadığı için görsel kırpılıyor, alanlar kayıyordu.
Çözüm: lib/core/ui/image_stage.dart. Görsel oranı korunarak sığdırılır (kırpma yok),
tüm alanlar görselin kendi boyutuna göre yerleştirilir. Ekran oranı değişse de kaymaz.
test/core/image_stage_test.dart bu hizayı farklı ekran oranlarında doğrular.
Hata ayıklama için: --dart-define=ARES_DEBUG_HITBOX=true ile alanlar kırmızı görünür.

## Senaryoya göre eklenenler
- Ana ekran: PNG aynen duruyor; sağ sütun (Canlı Operasyon, Ajan Durumları, Son İşlemler, Sistem Bildirimleri)
  ve Sistem Durumu artık CIO/CEO tarafından canlı besleniyor.
- Sohbet: PNG + hizalı alanlar; sol menü (geçmiş, görevler, dosyalar, görsel analiz, notlar, arşiv) çalışır.
- Dinleyici → CEO → ekipler → CEO onayı → kullanıcı hattı (OfficeService). CEO işi en fazla 3 kez geri gönderir,
  düzelmezse ayrıntılı rapor ve tavsiye verir.
- Yapay zekâ sağlayıcı kataloğu (6 kategori), renk kuralları, model sıralaması, günlük sayaç, kota dolunca
  sıradakine devretme, ücretli AI için onay, API anahtarları, yedek/geri yükleme (Ayarlar).
- AI Radar: etkin sağlayıcıların yeni modellerini ve hazır öneri listesindeki erişilebilir servisleri bulur,
  hiçbirini onaysız eklemez.
- CIO: ~3 dakikada bir rutin kontrol, sorun + çözüm raporu. Güvenlik ajanı: üretilen koda kural tabanlı tarama.
- Eğitim klasörü: önce buraya bakılır; aynı soru varsa yapay zekâ harcanmaz; benzer çalışma referans olur.

## Henüz YOK (dürüst liste)
- Sesli komut ve sesli cevap, dosya seçici: native eklenti gerekir, derlenen yapıyı bozma riski nedeniyle eklenmedi.
  (Klavyedeki mikrofon simgesiyle konuşup yazdırabilirsiniz; belge metni yapıştırılabilir.)
- Tablet içinde çalışan yerleşik açık kaynak model: yok. Varsayılan "ARES Çekirdek" bir Ollama adresine bağlanır.
- Görsel analiz, API anahtarının şifreli saklanması, uygulama kapalıyken arka plan çalışma.
- AI Radar internette serbest araştırma yapmaz; ücret/kotayı doğrulamaz.
- Kod derlenmeden yazıldı; ilk GitHub derlemesinde hata çıkarsa Actions > analiz-ve-test-raporlari dosyasını veya günlüğü iletin.

## Görsel güncellemesi
assets/images/ares_ana_ekran.png yeni görselle (1536x1024, 3:2) değiştirildi; "Şirket Sahibi" ve "İbrahim Halil Ezen" plakaları eklendi. Sistem Durumu canlı katmanı yeni nokta konumuna göre ayarlandı.

## Tam ekran
Uygulama tam ekran (immersiveSticky) açılır; çubuklar kenardan kaydırınca geçici görünür. Ana ekran ve sohbet görseli ekranın tamamını doldurur (2400x1600 = 3:2 için kırpma ve boşluk yok).
