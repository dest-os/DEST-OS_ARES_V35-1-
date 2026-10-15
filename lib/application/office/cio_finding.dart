/// CIO veya güvenlik ajanının bulduğu tek bir sorun/uyarı.
class CioFinding {
  const CioFinding({required this.area, required this.level, required this.text, this.fix = ''});

  /// Sistem, AI altyapısı, Güvenlik, Veri, Teknik destek
  final String area;

  /// info, ok, warn, error
  final String level;
  final String text;

  /// Önerilen çözüm yolu.
  final String fix;
}
