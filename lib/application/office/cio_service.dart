import 'dart:async';
import 'dart:io';

import '../../domain/office/ai_provider.dart';
import '../../infrastructure/storage/json_file_store.dart';
import '../archive/work_archive_repository.dart';
import 'approval_store.dart';
import 'cio_finding.dart';
import 'office_hub.dart';
import 'provider_store.dart';

/// İnternet bağlantısı var mı.
typedef InternetProbe = Future<bool> Function();

Future<bool> defaultInternetProbe() async {
  try {
    final result = await InternetAddress.lookup('example.com').timeout(const Duration(seconds: 4));
    return result.isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// CIO: sistemin rutin kontrollerini yapar, sorunlu bölgeleri raporlar,
/// çözüm yolu önerir ve ana ekrandaki bilgilendirme sütununu canlı besler.
class CioService {
  CioService({
    required this.hub,
    required this.providers,
    required this.approvals,
    required this.archive,
    required JsonFileStore store,
    InternetProbe? internetProbe,
  })  : _store = store,
        _probe = internetProbe ?? defaultInternetProbe;

  final OfficeHub hub;
  final ProviderStore providers;
  final ApprovalStore approvals;
  final WorkArchiveRepository archive;
  final JsonFileStore _store;
  final InternetProbe _probe;

  Timer? _timer;
  bool _running = false;
  String _lastSignature = '';
  List<CioFinding> _lastReport = const <CioFinding>[];
  DateTime? _lastRunAt;

  List<CioFinding> get lastReport => _lastReport;
  DateTime? get lastRunAt => _lastRunAt;

  /// İlk kontrolü hemen yapar, sonra düzenli aralıkla tekrarlar.
  void start({Duration interval = const Duration(minutes: 3)}) {
    _timer?.cancel();
    unawaited(runRoutineCheck());
    _timer = Timer.periodic(interval, (_) => unawaited(runRoutineCheck()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<List<CioFinding>> runRoutineCheck() async {
    if (_running) return _lastReport;
    _running = true;
    hub.setAgent('cio', 'Rutin kontrol yapıyor');
    final findings = <CioFinding>[];
    try {
      final online = await _probe();
      if (!online) {
        findings.add(const CioFinding(
          area: 'Sistem',
          level: 'warn',
          text: 'İnternet bağlantısı yok.',
          fix: 'Wi-Fi veya mobil veriyi kontrol edin. Yerel yapay zekâ internet gerektirmez.',
        ));
      }

      final today = providers.today;
      final usable = providers.callable.where((p) {
        if (!p.configured) return false;
        if (p.statusAt(today) == ProviderStatus.limitReached) return false;
        if (p.category == ProviderCategory.paid && !p.paidApproved) return false;
        return true;
      }).toList();
      final aiOk = usable.isNotEmpty;
      if (!aiOk) {
        findings.add(const CioFinding(
          area: 'AI altyapısı',
          level: 'warn',
          text: 'Çalışabilir yapay zekâ yok.',
          fix: 'Ayarlar > AI Kataloğu: bir sağlayıcıyı etkinleştirin ve adres, model, (gerekiyorsa) anahtarı girin. '
              'Yerel çekirdek için aynı ağdaki bir bilgisayarda Ollama çalıştırıp adresini girebilirsiniz.',
        ));
      }
      for (final p in providers.ordered) {
        if (p.enabled && p.chat && !p.configured && !p.deprecated) {
          findings.add(CioFinding(
            area: 'AI altyapısı',
            level: 'warn',
            text: '${p.name}: etkin ama adres, model veya anahtar eksik.',
            fix: 'Ayarlar > API Anahtarları bölümünden eksik alanları doldurun.',
          ));
        }
        if (p.enabled && p.deprecated) {
          findings.add(CioFinding(
            area: 'AI altyapısı',
            level: 'warn',
            text: '${p.name}: kullanımdan kalkmış olarak işaretli ama etkin.',
            fix: 'Katalogdan silin veya başka bir sağlayıcı seçin.',
          ));
        }
        if (p.enabled && p.statusAt(today) == ProviderStatus.limitReached) {
          findings.add(CioFinding(
            area: 'AI altyapısı',
            level: 'info',
            text: '${p.name}: bugünkü kota doldu; işler sıradaki yapay zekâya devrediliyor.',
            fix: 'Yarın otomatik açılır; isterseniz Kullanım & Limitler bölümünden sıfırlayın.',
          ));
        }
      }

      if (approvals.pendingCount > 0) {
        findings.add(CioFinding(
          area: 'Sistem',
          level: 'info',
          text: '${approvals.pendingCount} onay bekliyor.',
          fix: 'Ayarlar > Onaylar bölümünden karar verin.',
        ));
      }

      var storageOk = true;
      try {
        final stamp = DateTime.now().millisecondsSinceEpoch;
        await _store.write('health_probe', <String, Object?>{'t': stamp});
        final back = await _store.read('health_probe');
        storageOk = back is Map && back['t'] == stamp;
      } catch (_) {
        storageOk = false;
      }
      if (!storageOk) {
        findings.add(const CioFinding(
          area: 'Veri',
          level: 'error',
          text: 'Cihaz depolamasına yazılamıyor; ayarlar ve Eğitim kayıtları kaybolabilir.',
          fix: 'Cihazda boş yer olduğundan emin olun, uygulamayı yeniden başlatın.',
        ));
      }

      try {
        final entries = await archive.search('');
        if (entries.length > 150) {
          findings.add(CioFinding(
            area: 'Veri',
            level: 'info',
            text: 'Eğitim klasöründe ${entries.length} kayıt var.',
            fix: 'Eğitim ekranından eski ve önemsiz kayıtları silin; hangisinin kalacağına siz karar verirsiniz.',
          ));
        }
      } catch (_) {
        // Arşiv okunamazsa depolama kontrolü zaten uyarır.
      }

      if (providers.ordered.any((p) => p.hasKey)) {
        findings.add(const CioFinding(
          area: 'Güvenlik',
          level: 'info',
          text: 'API anahtarları bu cihazda uygulamanın özel alanında düz dosya olarak saklanıyor.',
          fix: 'Cihazınıza başkası erişmesin; şifreli depolama sonraki sürümde eklenecek.',
        ));
      }
    } catch (error) {
      findings.add(CioFinding(area: 'Sistem', level: 'error', text: 'Rutin kontrol hata verdi: $error'));
    }

    final securityBad = findings.any((f) => f.area == 'Güvenlik' && (f.level == 'warn' || f.level == 'error'));
    hub.setSystemStatus(<String, bool>{
      'ai': findings.every((f) => f.area != 'AI altyapısı' || f.level == 'info'),
      'internet': !findings.any((f) => f.text == 'İnternet bağlantısı yok.'),
      'sync': !findings.any((f) => f.area == 'Veri' && f.level == 'error'),
      'security': !securityBad,
    });

    final signature = findings.map((f) => '${f.level}:${f.text}').join('|');
    if (signature != _lastSignature) {
      _lastSignature = signature;
      final problems = findings.where((f) => f.level == 'warn' || f.level == 'error').length;
      hub.log(
        problems == 0 ? 'CIO rutin kontrol: sorun yok.' : 'CIO rutin kontrol: $problems sorun bulundu.',
        level: problems == 0 ? 'ok' : 'warn',
      );
      for (final f in findings) {
        if (f.level == 'warn' || f.level == 'error') hub.notify('${f.text} ${f.fix}', level: f.level);
      }
    }

    _lastReport = findings;
    _lastRunAt = DateTime.now();
    hub.setAgent('cio', '');
    _running = false;
    return findings;
  }
}
