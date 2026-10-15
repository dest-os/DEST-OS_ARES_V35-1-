import '../../infrastructure/storage/json_file_store.dart';

/// Kullanıcının Ayarlar ekranında girdiği yapay zekâ bağlantı bilgileri.
class AresSettings {
  /// Varsayılan olarak yerel AI kapalıdır (tablette Ollama çalışmaz).
  const AresSettings({
    this.localEnabled = false,
    this.localBaseUrl = 'http://localhost:11434',
    this.localModel = 'qwen3:4b',
    this.freeBaseUrl = '',
    this.freeModel = '',
    this.freeApiKey = '',
  });

  final bool localEnabled;
  final String localBaseUrl;
  final String localModel;
  final String freeBaseUrl;
  final String freeModel;
  final String freeApiKey;

  /// Uzak (ücretsiz / sınırlı ücretsiz) sağlayıcı için gerekli alanlar dolu mu?
  bool get freeConfigured => freeBaseUrl.trim().isNotEmpty && freeModel.trim().isNotEmpty;

  /// En az bir sağlayıcı kullanılabilir durumda mı?
  bool get anyConfigured => localEnabled || freeConfigured;

  AresSettings copyWith({
    bool? localEnabled,
    String? localBaseUrl,
    String? localModel,
    String? freeBaseUrl,
    String? freeModel,
    String? freeApiKey,
  }) {
    return AresSettings(
      localEnabled: localEnabled ?? this.localEnabled,
      localBaseUrl: localBaseUrl ?? this.localBaseUrl,
      localModel: localModel ?? this.localModel,
      freeBaseUrl: freeBaseUrl ?? this.freeBaseUrl,
      freeModel: freeModel ?? this.freeModel,
      freeApiKey: freeApiKey ?? this.freeApiKey,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'localEnabled': localEnabled,
        'localBaseUrl': localBaseUrl,
        'localModel': localModel,
        'freeBaseUrl': freeBaseUrl,
        'freeModel': freeModel,
        'freeApiKey': freeApiKey,
      };

  factory AresSettings.fromJson(Map<String, dynamic> json, {AresSettings defaults = const AresSettings()}) {
    String text(String key, String fallback) {
      final value = json[key];
      return value is String ? value : fallback;
    }

    final enabled = json['localEnabled'];
    return AresSettings(
      localEnabled: enabled is bool ? enabled : defaults.localEnabled,
      localBaseUrl: text('localBaseUrl', defaults.localBaseUrl),
      localModel: text('localModel', defaults.localModel),
      freeBaseUrl: text('freeBaseUrl', defaults.freeBaseUrl),
      freeModel: text('freeModel', defaults.freeModel),
      freeApiKey: text('freeApiKey', defaults.freeApiKey),
    );
  }
}

/// Ayarları diskten yükler, bellekte tutar ve kaydeder.
class AresSettingsStore {
  AresSettingsStore({required JsonFileStore store, AresSettings defaults = const AresSettings()})
      : _store = store,
        _defaults = defaults,
        _current = defaults;

  static const String _fileName = 'ares_settings';

  final JsonFileStore _store;
  final AresSettings _defaults;
  AresSettings _current;

  /// Şu an geçerli ayarlar. Gateway her istekte buradan okur.
  AresSettings get current => _current;

  /// Diskteki ayarları yükler; yoksa varsayılanlar kullanılır.
  Future<void> load() async {
    final raw = await _store.read(_fileName);
    if (raw is Map) {
      _current = AresSettings.fromJson(Map<String, dynamic>.from(raw), defaults: _defaults);
    }
  }

  /// Ayarları değiştirir ve diske yazar.
  Future<void> save(AresSettings settings) async {
    _current = settings;
    await _store.write(_fileName, settings.toJson());
  }
}
