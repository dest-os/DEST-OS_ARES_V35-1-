import 'code_validator_service.dart';

/// CEO'nun hata yorumlama ve başarısız işler için ayrıntılı rapor yazma görevi.
///
/// Kural tabanlıdır (ekstra yapay zekâ çağrısı ve token harcamaz): doğrulayıcının
/// ve sağlayıcının hata metinlerini tanır, nedenini açıklar, düzeltme talimatı
/// verir. Talimat, onarım yapan ajanın prompt'una eklenir.
class CeoReviewService {
  const CeoReviewService();

  static const List<_Rule> _rules = <_Rule>[
    _Rule(
      keys: <String>['eksik relative import'],
      cause: 'Bir dosya, henüz üretilmemiş başka bir dosyayı içe aktarıyor.',
      instruction: 'Import yolunu var olan bir dosyaya çevir veya eksik dosyayı da üret.',
    ),
    _Rule(
      keys: <String>['parantez', 'süslü', 'köşeli', 'dengesiz', 'kapanmamış'],
      cause: 'Dosyada açılan parantez veya süslü parantezler kapanmamış (çıktı yarıda kesilmiş olabilir).',
      instruction: 'Dosyayı baştan sona eksiksiz yaz; tüm ( [ { işaretlerini kapat.',
    ),
    _Rule(
      keys: <String>['aynı artifact yolu'],
      cause: 'Aynı dosya yolu birden fazla kez üretilmiş.',
      instruction: 'Her dosya yolu için yalnızca tek bir artifact döndür.',
    ),
    _Rule(
      keys: <String>['güvenli olmayan artifact yolu'],
      cause: 'Dosya yolu proje klasörünün dışına çıkıyor.',
      instruction: 'Yalnızca proje köküne göre göreli yollar kullan (başında / veya .. olmasın).',
    ),
    _Rule(
      keys: <String>['pubspec'],
      cause: 'pubspec.yaml dosyasının biçimi veya zorunlu alanları hatalı.',
      instruction: 'pubspec.yaml içinde name, environment, dependencies ve flutter bölümlerini iki boşluk girintiyle yaz.',
    ),
    _Rule(
      keys: <String>['geçersiz json', 'artifact'],
      cause: 'Model, istenen JSON artifact biçimine uymayan bir cevap verdi.',
      instruction: 'Yalnızca {"artifacts":[...]} biçiminde geçerli JSON döndür; açıklama veya Markdown çiti ekleme.',
    ),
  ];

  static const List<_Rule> _connectionRules = <_Rule>[
    _Rule(
      keys: <String>['http 401', 'http 403'],
      cause: 'API anahtarı geçersiz veya yetkisiz.',
      instruction: 'Ayarlar ekranında anahtarı sağlayıcı sitesinden yeniden kopyalayıp "Kaydet ve test et" ile dene.',
    ),
    _Rule(
      keys: <String>['http 429'],
      cause: 'Sağlayıcının ücretsiz kotası veya hız sınırı doldu.',
      instruction: 'Biraz bekleyin veya Ayarlar\'dan başka bir sağlayıcı/model seçin.',
    ),
    _Rule(
      keys: <String>['http 404'],
      cause: 'Adres veya model adı yanlış.',
      instruction: 'Ayarlar\'da adresi ve model adını sağlayıcının sitesindeki yazımla birebir aynı yapın.',
    ),
    _Rule(
      keys: <String>['zaman aşım'],
      cause: 'Sağlayıcı zamanında cevap vermedi (yavaş model veya zayıf internet).',
      instruction: 'İnterneti kontrol edin veya daha hızlı/küçük bir model seçin.',
    ),
    _Rule(
      keys: <String>['yapılandırılmamış', 'ayarlanmamış'],
      cause: 'Yapay zekâ bağlantısı henüz ayarlanmamış.',
      instruction: 'Ana ekranda CEO — Ayarlar bölümünden adres, model ve anahtarı girin.',
    ),
    _Rule(
      keys: <String>['bağlantısı başarısız', 'erişilemiyor', 'socketexception'],
      cause: 'Sağlayıcıya ulaşılamadı.',
      instruction: 'İnternet bağlantısını ve Ayarlar\'daki adresi kontrol edin.',
    ),
  ];

  /// Onarım yapan ajana verilecek CEO teşhisi ve talimatı.
  String diagnose(CodeValidationReport report) {
    final lines = _matched(report.errors, _rules);
    if (lines.isEmpty) {
      return '- Genel: Hata listesindeki her maddeyi tek tek düzelt; hata olmayan kısımları değiştirme.';
    }
    return lines.map((rule) => '- ${rule.cause} → ${rule.instruction}').join('\n');
  }

  /// Başarısız bir üretim için kullanıcıya gösterilecek ayrıntılı Markdown rapor.
  String buildFailureReport({
    required String request,
    required List<String> errors,
    required List<String> logs,
    required int retryCount,
    required int selfHealingCount,
    required int maxSelfHealing,
  }) {
    final causes = <_Rule>[
      ..._matched(errors, _connectionRules),
      ..._matched(errors, _rules),
    ];
    final attempts = logs
        .where((l) => l.contains('self-healing') || l.contains('tekrar denemesi') || l.contains('Hata:'))
        .toList();
    final recentAttempts = attempts.length > 10 ? attempts.sublist(attempts.length - 10) : attempts;

    final b = StringBuffer()
      ..writeln('ÜRETİM TAMAMLANAMADI — CEO RAPORU')
      ..writeln()
      ..writeln('1) Ne istendi')
      ..writeln(_clip(request, 240))
      ..writeln()
      ..writeln('2) Neresi bozuldu');
    final shownErrors = errors.take(6).toList();
    for (final error in shownErrors) {
      b.writeln('- ${_clip(error, 220)}');
    }
    if (errors.length > shownErrors.length) {
      b.writeln('- … ve ${errors.length - shownErrors.length} hata daha.');
    }
    b
      ..writeln()
      ..writeln('3) Neden (CEO teşhisi)');
    if (causes.isEmpty) {
      b.writeln('- Net bir neden belirlenemedi; hata satırlarına bakın.');
    } else {
      for (final rule in causes) {
        b.writeln('- ${rule.cause}');
      }
    }
    b
      ..writeln()
      ..writeln('4) Neler denendi')
      ..writeln('- Aşama yeniden denemesi: $retryCount, otomatik onarım: $selfHealingCount (en fazla $maxSelfHealing).');
    for (final line in recentAttempts) {
      b.writeln('- ${_clip(line, 160)}');
    }
    b
      ..writeln()
      ..writeln('5) Önerilerim');
    final tips = <String>[
      for (final rule in causes) rule.instruction,
      'İsteği küçültün: önce tek bir ekran veya özellik isteyin, sonra ekleyin.',
      'Ayarlar\'dan başka bir model deneyin ve "Kaydet ve test et" ile bağlantıyı doğrulayın.',
    ];
    final unique = <String>{...tips}.take(4).toList();
    for (var i = 0; i < unique.length; i++) {
      b.writeln('${i + 1}. ${unique[i]}');
    }
    return b.toString().trimRight();
  }

  List<_Rule> _matched(List<String> errors, List<_Rule> rules) {
    final lower = errors.map((e) => e.toLowerCase()).toList();
    final result = <_Rule>[];
    for (final rule in rules) {
      final hit = lower.any((e) => rule.keys.any(e.contains));
      if (hit) result.add(rule);
    }
    return result;
  }

  String _clip(String value, int max) {
    final flat = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.length <= max ? flat : '${flat.substring(0, max)}…';
  }
}

class _Rule {
  const _Rule({required this.keys, required this.cause, required this.instruction});

  final List<String> keys;
  final String cause;
  final String instruction;
}
