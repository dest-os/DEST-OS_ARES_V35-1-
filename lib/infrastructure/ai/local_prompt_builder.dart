/// Qwen3 için ChatML biçiminde komut (prompt) hazırlar.
///
/// Qwen3 komut verilmiş (instruct) bir modeldir; ham metin yerine sohbet
/// biçimi gerekir. "Düşünme" modu kapatılır, aksi halde sınırlı token
/// bütçesi düşünceye harcanır ve cevap boş kalır.
class LocalPromptBuilder {
  const LocalPromptBuilder();

  static const String systemText =
      'Sen ARES\'sin, Türkçe konuşan yardımcı bir asistansın. '
      'Kısa, doğru ve düzenli cevap ver. Bilmediğin bir şeyi uydurma; bilmiyorsan "bilmiyorum" de.';

  /// Bir token için ortalama karakter sayısı (Türkçe için ihtiyatlı değer).
  static const double _charsPerToken = 2.5;

  /// [instruction] metnini bağlam penceresine sığacak şekilde kısaltıp ChatML'e sarar.
  String build(
    String instruction, {
    required int contextTokens,
    required int maxTokens,
  }) {
    final budgetTokens = contextTokens - maxTokens - 110;
    final safeTokens = budgetTokens < 96 ? 96 : budgetTokens;
    final budgetChars = (safeTokens * _charsPerToken).floor();
    final text = _fit(instruction.trim(), budgetChars);
    return '<|im_start|>system\n$systemText<|im_end|>\n'
        '<|im_start|>user\n$text<|im_end|>\n'
        '<|im_start|>assistant\n<think>\n\n</think>\n\n';
  }

  /// Uzun metnin başını (rol ve kurallar) ve sonunu (asıl istek) korur, ortasını keser.
  String _fit(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    const marker = '\n[...kısaltıldı...]\n';
    final head = (maxChars * 0.3).floor();
    final tail = maxChars - head - marker.length;
    if (tail <= 0) return text.substring(text.length - maxChars);
    return '${text.substring(0, head)}$marker${text.substring(text.length - tail)}';
  }
}

/// Modelin ham çıktısını kullanıcıya gösterilecek metne çevirir.
class LocalOutputCleaner {
  const LocalOutputCleaner();

  String clean(String raw) {
    var text = raw;
    // Tamamlanmış düşünme blokları.
    text = text.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '');
    // Kapanmamış düşünme bloğu: token sınırında kesilmiştir, düşünceyi at.
    final open = text.indexOf('<think>');
    if (open >= 0) text = text.substring(0, open);
    for (final tag in const <String>[
      '</think>',
      '<|im_end|>',
      '<|im_start|>',
      '<|endoftext|>',
    ]) {
      text = text.replaceAll(tag, '');
    }
    text = text.replaceFirst(RegExp(r'^\s*assistant\s*\n'), '');
    return text.trim();
  }
}
