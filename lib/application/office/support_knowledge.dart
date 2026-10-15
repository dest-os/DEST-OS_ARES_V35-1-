/// Teknik Destek ajanının çevrimdışı bilgi tabanı (yapay zekâ gerekmez).
class SupportKnowledge {
  const SupportKnowledge();

  static const List<_Entry> _entries = <_Entry>[
    _Entry(
      keys: <String>['api anahtar', 'anahtar', 'yapay zeka bağla', 'yapay zekâ bağla', 'nasıl bağla', 'ayarlar'],
      answer: 'Yapay zekâ bağlamak için ana ekranda ortadaki CEO masasındaki göze dokunun. '
          'Ayarlar > AI Kataloğu\'ndan bir sağlayıcıya dokunun, adresini ve model adını kontrol edin, '
          'API anahtarını kendiniz girip "Etkin" anahtarını açın. "Kaydet ve test et" ile bağlantıyı deneyin.',
    ),
    _Entry(
      keys: <String>['ücretli', 'ücret', 'para'],
      answer: 'Ücretli yapay zekâ onayınız olmadan hiç kullanılmaz. Ücretli bir sağlayıcı sıraya gelirse '
          'Ayarlar > Onaylar bölümünde bir onay isteği açılır; yalnızca siz onaylarsanız kullanılır.',
    ),
    _Entry(
      keys: <String>['renk', 'yeşil', 'sarı', 'mavi', 'kırmızı', 'kota', 'limit'],
      answer: 'Katalogdaki renkler: yeşil = kullanımda, sarı = sınırlı kullanım veya günlük kota var, '
          'mavi = kota doldu (iş otomatik sıradaki yapay zekâya geçer), kırmızı = kullanımdan kalkmış (yanındaki çöp kutusuyla silebilirsiniz), '
          'gri = etkin değil.',
    ),
    _Entry(
      keys: <String>['eğitim klasör', 'arşiv', 'kayıt', 'sil', 'geçmiş çalışma'],
      answer: 'Başarılı işler Eğitim klasörüne "gün ay yıl — konu" başlığıyla kaydedilir. Her kaydın yanındaki '
          'çöp kutusuyla siz silersiniz; kalıp kalmayacağına siz karar verirsiniz. Benzer bir istek yazdığınızda '
          'önce bu klasöre bakılır, böylece gereksiz yapay zekâ harcaması azalır.',
    ),
    _Entry(
      keys: <String>['mikrofon', 'sesli', 'ses ', 'konuş', 'dinle'],
      answer: 'Sohbet ekranındaki mikrofon düğmesine basıp konuşun; konuşmanız yazıya çevrilir. '
          'Cevapları sesli dinlemek için hoparlör düğmesini açın. İlk kullanımda mikrofon izni istenir. '
          'Sesli komut için cihazınızda Türkçe konuşma tanıma açık olmalıdır.',
    ),
    _Entry(
      keys: <String>['dosya', 'ekle', 'yükle', 'paylaş'],
      answer: 'Sohbette ataç (ataç simgesi) düğmesiyle dosya seçebilirsiniz. Metin dosyaları (txt, md, json, dart, csv vb.) '
          'okunup isteğinizle birlikte ekibe iletilir. Görseller şimdilik yalnızca önizlenir; görsel çözümleme için görüntü destekli bir model gerekir.',
    ),
    _Entry(
      keys: <String>['ceo', 'ekip', 'nasıl çalış', 'hata', 'tekrar'],
      answer: 'İsteğiniz önce Dinleyici\'ye gelir, CEO\'ya iletilir. CEO konuya göre ekipleri seçer, işi parçalara böler, ekip çıktıyı CEO\'ya geri verir. '
          'CEO eksik veya hatalı bulursa ekibe en fazla 3 kez geri gönderir. Düzelmezse ayrıntılı rapor ve tavsiyeyle size iletilir.',
    ),
    _Entry(
      keys: <String>['uygulama yap', 'uygulama üret', 'apk', 'kod üret', 'program yap'],
      answer: 'Sohbette örneğin "görev takip uygulaması yap" yazın. İstek Geliştirme Ekibi\'ne gider; çıktı dosyalar halinde '
          '(her özellik ayrı dosya) üretilir ve Güvenlik ajanı taramadan geçirir. Ana ekranda "Geliştirme Ekibi"ne dokunarak Üretim Merkezi\'ni de açabilirsiniz.',
    ),
    _Entry(
      keys: <String>['yedek', 'geri yükle', 'yedekle'],
      answer: 'Ayarlar > Yedekle / Geri Yükle bölümü AI kataloğunu panoya kopyalar veya panodan geri yükler. '
          'API anahtarları varsayılan olarak yedeğe dahil edilmez.',
    ),
    _Entry(
      keys: <String>['radar', 'yeni ai', 'yeni yapay'],
      answer: 'AI Radar, etkin sağlayıcılarınızın model listesindeki yenilikleri ve hazır öneri listesindeki erişilebilir servisleri bulur. '
          'Hiçbirini onayınız olmadan eklemez; önerileri Ayarlar > Onaylar bölümünde görürsünüz. Radar ücret veya kotayı doğrulamaz, '
          'bu bilgiyi sağlayıcının sitesinden kontrol edin.',
    ),
  ];

  /// En çok anahtar kelime eşleşen cevabı döndürür; eşleşme yoksa null.
  String? answer(String question) {
    final q = question.toLowerCase();
    String? best;
    var bestScore = 0;
    for (final entry in _entries) {
      var score = 0;
      for (final key in entry.keys) {
        if (q.contains(key)) score += 1;
      }
      if (score > bestScore) {
        bestScore = score;
        best = entry.answer;
      }
    }
    return best;
  }
}

class _Entry {
  const _Entry({required this.keys, required this.answer});

  final List<String> keys;
  final String answer;
}
