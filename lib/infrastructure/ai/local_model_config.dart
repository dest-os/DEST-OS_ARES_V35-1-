/// ARES yerel yapay zekâ modelinin yapılandırması.
class LocalModelConfig {
  LocalModelConfig._();

  /// Model deposu (resmi ggml-org GGUF dönüşümü).
  static const String repository = 'ggml-org/Qwen3-0.6B-GGUF';

  /// İndirilecek GGUF dosyasının adı.
  static const String fileName = 'Qwen3-0.6B-Q4_0.gguf';

  /// İndirme adresi.
  static const String downloadUrl =
      'https://huggingface.co/ggml-org/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q4_0.gguf';

  /// Yaklaşık dosya boyutu (bayt). Yalnızca ilerleme göstermek için kullanılır;
  /// kesin boyut doğrulaması yapılmaz (indirici HTTP uzunluğunu ve GGUF imzasını denetler).
  static const int approxSizeBytes = 429 * 1024 * 1024;

  /// Kesin dosya boyutu doğrulaması (0 = kapalı). İndirici bunun yerine
  /// HTTP içerik uzunluğunu ve GGUF imzasını denetler.
  static const int expectedSizeBytes = 0;

  /// Varsayılan (en büyük) bağlam boyutu.
  static const int contextSize = 2048;

  /// Model yükleme denemeleri: bağlam boyutları büyükten küçüğe denenir.
  /// 0.6B model için 2048 bağlamın bellek yükü yaklaşık 230 MB'tır.
  static const List<int> contextFallbacks = <int>[2048, 1024, 512];

  /// İşlemci iş parçacığı sayısı.
  static const int threads = 4;

  /// Metin üretim ayarları.
  static const int maxTokens = 320;
  static const double temperature = 0.3;

  /// Tek bir üretimde olay (token) arası en uzun bekleme.
  static const Duration tokenTimeout = Duration(seconds: 90);
}
