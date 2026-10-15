import '../../domain/office/ai_provider.dart';
import '../../infrastructure/storage/json_file_store.dart';
import '../office/approval_store.dart';
import '../office/office_hub.dart';
import '../office/provider_catalog_seed.dart';
import '../office/provider_store.dart';
import 'model_list_fetcher.dart';

/// Radar taramasının özeti.
class RadarResult {
  const RadarResult({this.newModels = 0, this.newSuggestions = 0, this.errors = const <String>[], this.skipped = false});

  final int newModels;
  final int newSuggestions;
  final List<String> errors;
  final bool skipped;
}

/// AI Radar: etkin sağlayıcıların model listesindeki yenilikleri bulur ve
/// hazır öneri listesindeki erişilebilir servisleri kullanıcıya onaya sunar.
///
/// Radar internette serbest araştırma YAPMAZ ve hiçbir şeyi onaysız eklemez.
/// Ücret/kota bilgisini doğrulamaz; yalnızca adresin erişilebilir olduğunu kontrol eder.
class ModelRadarService {
  ModelRadarService({
    required JsonFileStore store,
    required ProviderStore providers,
    required ApprovalStore approvals,
    required ModelListFetcher fetcher,
    this.hub,
    DateTime Function()? clock,
  })  : _store = store,
        _providers = providers,
        _approvals = approvals,
        _fetcher = fetcher,
        _clock = clock ?? DateTime.now;

  static const String _fileName = 'model_radar';
  static const Duration _interval = Duration(hours: 24);

  final JsonFileStore _store;
  final ProviderStore _providers;
  final ApprovalStore _approvals;
  final ModelListFetcher _fetcher;
  final OfficeHub? hub;
  final DateTime Function() _clock;

  /// Son tarama zamanı (yoksa null).
  Future<DateTime?> lastScanAt() async {
    final raw = await _store.read(_fileName);
    if (raw is Map && raw['lastScanAt'] is String) {
      return DateTime.tryParse(raw['lastScanAt'] as String);
    }
    return null;
  }

  /// [force] false ise son taramadan 24 saat geçmediyse atlar.
  Future<RadarResult> scan({bool force = false}) async {
    final raw = await _store.read(_fileName);
    final state = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

    final last = state['lastScanAt'] is String ? DateTime.tryParse(state['lastScanAt'] as String) : null;
    if (!force && last != null && _clock().difference(last) < _interval) {
      return const RadarResult(skipped: true);
    }

    final known = <String, List<String>>{};
    final knownRaw = state['known'];
    if (knownRaw is Map) {
      knownRaw.forEach((key, value) {
        if (key is String && value is List) {
          known[key] = value.whereType<String>().toList();
        }
      });
    }
    final suggested = <String>[];
    final suggestedRaw = state['suggested'];
    if (suggestedRaw is List) suggested.addAll(suggestedRaw.whereType<String>());

    hub?.setAgent('radar', 'Yeni AI\'ları tarıyor');
    final errors = <String>[];
    var newModels = 0;
    var newSuggestions = 0;

    for (final p in _providers.callable) {
      if (p.baseUrl.trim().isEmpty) continue;
      if (p.needsKey && !p.hasKey) continue;
      try {
        final models = await _fetcher.fetchModels(baseUrl: p.baseUrl, apiKey: p.apiKey);
        final before = known[p.id];
        if (before != null) {
          final fresh = models.where((m) => !before.contains(m)).take(5).toList();
          for (final m in fresh) {
            final created = await _approvals.request(
              kind: 'new_model',
              title: 'Yeni model: $m (${p.name})',
              detail: 'Onaylarsanız ${p.name} bu modelle çalışır.',
              refId: '${p.id}|$m',
            );
            if (created) {
              newModels += 1;
              hub?.notify('Yeni bir AI modeli keşfedildi: $m', level: 'info');
            }
          }
        }
        known[p.id] = models;
      } catch (error) {
        errors.add('${p.name}: model listesi alınamadı ($error)');
      }
    }

    for (final s in curatedSuggestions()) {
      if (_providers.byId(s.id) != null) continue;
      if (suggested.contains(s.id)) continue;
      if (_approvals.wasRejected('new_ai', s.id)) continue;
      final reachable = await _fetcher.isReachable(s.baseUrl);
      if (!reachable) {
        errors.add('${s.name}: adres erişilemedi, öneri ertelendi.');
        continue;
      }
      final created = await _approvals.request(
        kind: 'new_ai',
        title: 'Yeni AI önerisi: ${s.name}',
        detail: '${providerCategoryLabel(s.category)} • ${s.capabilities}\n'
            'API anahtarı sitesi: ${s.siteUrl}\n'
            'Adres erişilebilir. Ücret ve kota bilgisi doğrulanmadı; sağlayıcı sitesinden kontrol edin.',
        refId: s.id,
      );
      suggested.add(s.id);
      if (created) {
        newSuggestions += 1;
        hub?.notify('Yeni AI önerisi hazır: ${s.name}', level: 'info');
      }
    }

    await _store.write(_fileName, <String, Object?>{
      'lastScanAt': _clock().toIso8601String(),
      'known': known,
      'suggested': suggested,
    });
    hub?.setAgent('radar', '');
    hub?.log('AI Radar taraması bitti: $newModels yeni model, $newSuggestions yeni öneri.', level: 'ok');
    return RadarResult(newModels: newModels, newSuggestions: newSuggestions, errors: errors);
  }
}
