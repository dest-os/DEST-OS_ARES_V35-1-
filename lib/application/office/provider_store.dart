import 'package:flutter/foundation.dart';

import '../../domain/office/ai_provider.dart';
import '../../infrastructure/storage/json_file_store.dart';
import 'provider_catalog_seed.dart';

/// AI kataloğu, model sıralaması, günlük kullanım ve kota durumunu yönetir.
class ProviderStore extends ChangeNotifier {
  ProviderStore({required JsonFileStore store, DateTime Function()? clock})
      : _store = store,
        _clock = clock ?? DateTime.now;

  static const String _fileName = 'ai_providers';
  static const String _embeddedLocalProviderId = 'ares_embedded_local';

  final JsonFileStore _store;
  final DateTime Function() _clock;
  final List<AiProviderConfig> _providers = <AiProviderConfig>[];
  final List<String> _order = <String>[];
  final Map<String, String> _teamProvider = <String, String>{};

  /// Bugünün gün anahtarı.
  String get today => dayKey(_clock());

  /// Katalogdaki tüm sağlayıcılar (sıralamaya göre).
  List<AiProviderConfig> get ordered {
    final result = <AiProviderConfig>[];
    for (final id in _order) {
      final p = byId(id);
      if (p != null) result.add(p);
    }
    return result;
  }

  /// Kategoriye göre sağlayıcılar.
  List<AiProviderConfig> inCategory(ProviderCategory category) {
    return ordered.where((p) => p.category == category).toList();
  }

  /// Sohbet için çağrılabilir olanlar (etkin, kullanımdan kalkmamış), sıralı.
  List<AiProviderConfig> get callable {
    return ordered.where((p) => p.chat && p.enabled && !p.deprecated).toList();
  }

  /// Sıralama sekmesinde gösterilen sohbet sağlayıcıları.
  List<AiProviderConfig> get chatProviders =>
      ordered.where((p) => p.chat).toList();

  Map<String, String> get teamProvider =>
      Map<String, String>.unmodifiable(_teamProvider);

  AiProviderConfig? byId(String id) {
    for (final p in _providers) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Diskten yükler; eksikse başlangıç kataloğunu kurar.
  /// Yeni gömülü yerel AI sağlayıcısını mevcut kayıtları silmeden ekler.
  Future<void> load() async {
    final raw = await _store.read(_fileName);
    _providers.clear();
    _order.clear();
    _teamProvider.clear();

    if (raw is Map) {
      final list = raw['providers'];
      if (list is List) {
        for (final item in list) {
          if (item is Map) {
            try {
              final p =
                  AiProviderConfig.fromJson(Map<String, dynamic>.from(item));
              if (p.id.isNotEmpty) _providers.add(p);
            } catch (_) {
              // Bozuk kayıt atlanır.
            }
          }
        }
      }

      final order = raw['order'];
      if (order is List) {
        for (final id in order) {
          if (id is String) _order.add(id);
        }
      }

      final teams = raw['teamProvider'];
      if (teams is Map) {
        teams.forEach((key, value) {
          if (key is String && value is String) {
            _teamProvider[key] = value;
          }
        });
      }
    }

    if (_providers.isEmpty) {
      _providers.addAll(seedProviders());
    }

    // Var olan kullanıcı kayıtlarını koruyarak gömülü sağlayıcıyı ekle.
    if (byId(_embeddedLocalProviderId) == null) {
      for (final provider in seedProviders()) {
        if (provider.id == _embeddedLocalProviderId) {
          _providers.add(provider);
          // Çevrimdışı çalıştığı için sıralamada en başa konur.
          _order.remove(provider.id);
          _order.insert(0, provider.id);
          break;
        }
      }
    }

    // Eski sürümdeki 1.7B model etiketi yeni, daha hafif Android modeliyle
    // eşleştirilir. İndirme yolu config sınıfından alınır.
    final embedded = byId(_embeddedLocalProviderId);
    if (embedded != null &&
        embedded.model == 'Qwen3-1.7B-Q4_K_M.gguf') {
      final index = _providers.indexWhere(
        (p) => p.id == _embeddedLocalProviderId,
      );
      if (index >= 0) {
        _providers[index] = embedded.copyWith(
          model: 'Qwen3-0.6B-Q4_0.gguf',
        );
      }
    }

    // Ollama localhost sağlayıcısı tablette ayrı bir sunucu kurulmadıkça
    // çalışmaz. Gömülü AI etkinse yalnızca varsayılan Ollama kaydını kapat;
    // kullanıcı daha sonra ayarlardan tekrar etkinleştirebilir.
    final currentEmbedded = byId(_embeddedLocalProviderId);
    final ollama = byId('ares-core');
    if (currentEmbedded?.enabled == true &&
        ollama != null &&
        ollama.baseUrl == 'http://localhost:11434' &&
        ollama.model == 'qwen3:4b' &&
        ollama.enabled) {
      final index = _providers.indexWhere((p) => p.id == 'ares-core');
      if (index >= 0) {
        _providers[index] = ollama.copyWith(enabled: false);
      }
    }

    _normalizeOrder();
    await _save();
    notifyListeners();
  }

  void _normalizeOrder() {
    final known = _providers.map((p) => p.id).toSet();
    _order.removeWhere((id) => !known.contains(id));

    for (final p in _providers) {
      if (!_order.contains(p.id)) _order.add(p.id);
    }
  }

  Future<void> _save() async {
    await _store.write(_fileName, <String, Object?>{
      'providers': _providers.map((p) => p.toJson()).toList(),
      'order': _order,
      'teamProvider': _teamProvider,
    });
  }

  Future<void> _commit() async {
    _normalizeOrder();
    await _save();
    notifyListeners();
  }

  /// Sağlayıcı ekler veya aynı id'liyi değiştirir.
  Future<void> upsert(AiProviderConfig provider) async {
    final index = _providers.indexWhere((p) => p.id == provider.id);
    if (index >= 0) {
      _providers[index] = provider;
    } else {
      _providers.add(provider);
    }
    await _commit();
  }

  /// Sağlayıcıyı katalogdan siler.
  Future<void> remove(String id) async {
    _providers.removeWhere((p) => p.id == id);
    _order.remove(id);
    _teamProvider.removeWhere((key, value) => value == id);
    await _commit();
  }

  /// Sohbet sağlayıcılarının sırasını değiştirir.
  Future<void> reorderChat(int oldIndex, int newIndex) async {
    final chatIds = chatProviders.map((p) => p.id).toList();
    if (oldIndex < 0 || oldIndex >= chatIds.length) return;

    var target = newIndex;
    if (target > oldIndex) target -= 1;

    final id = chatIds.removeAt(oldIndex);
    if (target < 0) target = 0;
    if (target > chatIds.length) target = chatIds.length;
    chatIds.insert(target, id);

    final rest = _order.where((x) => !chatIds.contains(x)).toList();
    _order
      ..clear()
      ..addAll(chatIds)
      ..addAll(rest);

    await _commit();
  }

  /// Başarılı bir çağrıyı günlük sayaca işler.
  Future<void> recordUse(String id) async {
    final p = byId(id);
    if (p == null) return;

    final sameDay = p.usageDay == today;
    await upsert(
      p.copyWith(
        usageDay: today,
        usedToday: sameDay ? p.usedToday + 1 : 1,
      ),
    );
  }

  /// Kota dolduğunda sağlayıcıyı bugün için sınıra geldi yapar.
  Future<void> markLimit(String id) async {
    final p = byId(id);
    if (p == null) return;
    await upsert(p.copyWith(limitDay: today));
  }

  Future<void> clearLimit(String id) async {
    final p = byId(id);
    if (p == null) return;
    await upsert(p.copyWith(limitDay: '', usedToday: 0, usageDay: today));
  }

  /// Bir ekip için tercih edilen sağlayıcıyı ayarlar (null: otomatik).
  Future<void> setTeamProvider(String team, String? providerId) async {
    if (providerId == null || providerId.isEmpty) {
      _teamProvider.remove(team);
    } else {
      _teamProvider[team] = providerId;
    }
    await _commit();
  }

  /// Yedekleme için JSON; anahtarlar varsayılan olarak dışarıda bırakılır.
  Map<String, Object?> exportJson({bool includeKeys = false}) =>
      <String, Object?>{
        'providers':
            _providers.map((p) => p.toJson(includeKey: includeKeys)).toList(),
        'order': _order,
        'teamProvider': _teamProvider,
      };

  /// Yedeği geri yükler. Yedekte anahtar yoksa mevcut anahtarlar korunur.
  Future<void> importJson(Map<String, dynamic> data) async {
    final list = data['providers'];
    if (list is! List) {
      throw const FormatException('Yedekte "providers" listesi yok.');
    }

    final imported = <AiProviderConfig>[];
    for (final item in list) {
      if (item is Map) {
        var p = AiProviderConfig.fromJson(Map<String, dynamic>.from(item));
        if (p.apiKey.isEmpty) {
          final old = byId(p.id);
          if (old != null) p = p.copyWith(apiKey: old.apiKey);
        }
        if (p.id.isNotEmpty) imported.add(p);
      }
    }

    if (imported.isEmpty) {
      throw const FormatException('Yedekte sağlayıcı bulunamadı.');
    }

    _providers
      ..clear()
      ..addAll(imported);

    _order.clear();
    final order = data['order'];
    if (order is List) {
      for (final id in order) {
        if (id is String) _order.add(id);
      }
    }

    _teamProvider.clear();
    final teams = data['teamProvider'];
    if (teams is Map) {
      teams.forEach((key, value) {
        if (key is String && value is String) {
          _teamProvider[key] = value;
        }
      });
    }

    await _commit();
  }
}
