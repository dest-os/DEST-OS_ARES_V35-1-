/// Yapay zekâ sağlayıcı kategorileri (Ayarlar > AI Kataloğu bölümleri).
enum ProviderCategory { free, limitedFree, paid, local, tool, other }

/// Kataloğdaki rengi belirleyen durum.
/// inactive: gri, active: yeşil, limited: sarı, limitReached: mavi, deprecated: kırmızı.
enum ProviderStatus { inactive, active, limited, limitReached, deprecated }

String providerCategoryLabel(ProviderCategory category) {
  switch (category) {
    case ProviderCategory.free:
      return 'Ücretsiz AI\'lar';
    case ProviderCategory.limitedFree:
      return 'Sınırlı Ücretsiz AI\'lar';
    case ProviderCategory.paid:
      return 'Ücretli AI\'lar';
    case ProviderCategory.local:
      return 'Yerel AI\'lar';
    case ProviderCategory.tool:
      return 'Araç AI\'lar';
    case ProviderCategory.other:
      return 'Diğer AI\'lar';
  }
}

/// "2026-10-10" biçiminde gün anahtarı.
String dayKey(DateTime date) {
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '${date.year}-$m-$d';
}

/// Katalogdaki tek bir yapay zekâ sağlayıcısı.
class AiProviderConfig {
  AiProviderConfig({
    required this.id,
    required this.name,
    required this.vendor,
    required this.category,
    this.capabilities = '',
    this.baseUrl = '',
    this.model = '',
    this.apiKey = '',
    this.siteUrl = '',
    this.needsKey = true,
    this.enabled = false,
    this.deprecated = false,
    this.paidApproved = false,
    this.chat = true,
    this.verified = false,
    this.autoFilled = false,
    this.dailyLimit = 0,
    this.usedToday = 0,
    this.usageDay = '',
    this.limitDay = '',
  });

  final String id;
  final String name;
  final String vendor;
  final ProviderCategory category;
  final String capabilities;
  final String baseUrl;
  final String model;
  final String apiKey;
  final String siteUrl;
  final bool needsKey;
  final bool enabled;
  final bool deprecated;
  final bool paidApproved;

  /// Sohbet/metin üretimi için çağrılabilir mi (araç AI'lar için false).
  final bool chat;

  /// Adresin erişilebilir olduğu radar tarafından doğrulandı mı.
  final bool verified;

  /// Radar önerisinden otomatik dolduruldu mu.
  final bool autoFilled;
  final int dailyLimit;
  final int usedToday;
  final String usageDay;

  /// Kota dolduğu gün anahtarı (boşsa dolmadı).
  final String limitDay;

  bool get hasKey => apiKey.trim().isNotEmpty;

  /// Çağrılabilir için gerekli alanlar dolu mu.
  bool get configured {
    if (baseUrl.trim().isEmpty || model.trim().isEmpty) return false;
    if (needsKey && !hasKey) return false;
    return true;
  }

  ProviderStatus statusAt(String today) {
    if (deprecated) return ProviderStatus.deprecated;
    final reached = limitDay == today || (dailyLimit > 0 && usageDay == today && usedToday >= dailyLimit);
    if (reached) return ProviderStatus.limitReached;
    if (!enabled) return ProviderStatus.inactive;
    if (category == ProviderCategory.limitedFree || dailyLimit > 0) return ProviderStatus.limited;
    return ProviderStatus.active;
  }

  AiProviderConfig copyWith({
    String? name,
    String? baseUrl,
    String? model,
    String? apiKey,
    String? siteUrl,
    bool? enabled,
    bool? deprecated,
    bool? paidApproved,
    bool? verified,
    bool? autoFilled,
    int? dailyLimit,
    int? usedToday,
    String? usageDay,
    String? limitDay,
    ProviderCategory? category,
  }) {
    return AiProviderConfig(
      id: id,
      name: name ?? this.name,
      vendor: vendor,
      category: category ?? this.category,
      capabilities: capabilities,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
      siteUrl: siteUrl ?? this.siteUrl,
      needsKey: needsKey,
      enabled: enabled ?? this.enabled,
      deprecated: deprecated ?? this.deprecated,
      paidApproved: paidApproved ?? this.paidApproved,
      chat: chat,
      verified: verified ?? this.verified,
      autoFilled: autoFilled ?? this.autoFilled,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      usedToday: usedToday ?? this.usedToday,
      usageDay: usageDay ?? this.usageDay,
      limitDay: limitDay ?? this.limitDay,
    );
  }

  Map<String, Object?> toJson({bool includeKey = true}) => <String, Object?>{
        'id': id,
        'name': name,
        'vendor': vendor,
        'category': category.name,
        'capabilities': capabilities,
        'baseUrl': baseUrl,
        'model': model,
        'apiKey': includeKey ? apiKey : '',
        'siteUrl': siteUrl,
        'needsKey': needsKey,
        'enabled': enabled,
        'deprecated': deprecated,
        'paidApproved': paidApproved,
        'chat': chat,
        'verified': verified,
        'autoFilled': autoFilled,
        'dailyLimit': dailyLimit,
        'usedToday': usedToday,
        'usageDay': usageDay,
        'limitDay': limitDay,
      };

  static AiProviderConfig fromJson(Map<String, dynamic> json) {
    String text(String key) {
      final value = json[key];
      return value is String ? value : '';
    }

    bool flag(String key, bool fallback) {
      final value = json[key];
      return value is bool ? value : fallback;
    }

    int number(String key) {
      final value = json[key];
      return value is int ? value : 0;
    }

    var category = ProviderCategory.other;
    for (final c in ProviderCategory.values) {
      if (c.name == text('category')) category = c;
    }
    return AiProviderConfig(
      id: text('id'),
      name: text('name'),
      vendor: text('vendor'),
      category: category,
      capabilities: text('capabilities'),
      baseUrl: text('baseUrl'),
      model: text('model'),
      apiKey: text('apiKey'),
      siteUrl: text('siteUrl'),
      needsKey: flag('needsKey', true),
      enabled: flag('enabled', false),
      deprecated: flag('deprecated', false),
      paidApproved: flag('paidApproved', false),
      chat: flag('chat', true),
      verified: flag('verified', false),
      autoFilled: flag('autoFilled', false),
      dailyLimit: number('dailyLimit'),
      usedToday: number('usedToday'),
      usageDay: text('usageDay'),
      limitDay: text('limitDay'),
    );
  }
}
