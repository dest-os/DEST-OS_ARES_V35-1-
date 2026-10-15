import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';

import 'local_model_config.dart';
import 'local_model_storage.dart';
import 'local_prompt_builder.dart';

/// Cihaz içinde çalışan llama.cpp motorunu yönetir: yükleme, üretim, durdurma.
///
/// - Yükleme birden çok kez istenirse tek bir işlem paylaşılır ([ensureLoaded]).
/// - Bellek yetmezse bağlam boyutu küçültülerek yeniden denenir.
/// - Üretimler sıraya alınır (tek bağlam aynı anda tek işi yürütür).
class LocalModelService {
  LocalModelService({LlamaController? controller, LocalModelStorage? storage})
      : _controller = controller ?? LlamaController(),
        _storage = storage ?? LocalModelStorage();

  final LlamaController _controller;
  final LocalModelStorage _storage;
  final LocalPromptBuilder _promptBuilder = const LocalPromptBuilder();
  final LocalOutputCleaner _cleaner = const LocalOutputCleaner();

  bool _disposed = false;
  bool _loading = false;
  Future<bool>? _loadingFuture;
  Future<void> _tail = Future<void>.value();

  /// Son yükleme hatası (başarılı yüklemede boşalır).
  String lastError = '';

  /// Yüklenen modelin bağlam boyutu (token).
  int activeContext = 0;

  bool get isLoading => _loading;

  Future<bool> get isModelLoaded => _controller.isModelLoaded();

  /// Tek bir bağlam boyutuyla yüklemeyi dener ve yüklendiğini doğrular.
  Future<void> loadModel({
    required String modelPath,
    int threads = LocalModelConfig.threads,
    int contextSize = 2048,
  }) async {
    if (_disposed) {
      throw StateError('ARES yerel model servisi kapatılmış.');
    }
    final file = File(modelPath);
    if (!await file.exists()) {
      throw FileSystemException('Yerel model dosyası bulunamadı.', modelPath);
    }
    final size = await file.length();
    if (size == 0) {
      throw FileSystemException('Yerel model dosyası boş.', modelPath);
    }
    debugPrint('ARES_MODEL: yükleme başladı. boyut=$size ctx=$contextSize threads=$threads');
    await _controller.loadModel(
      modelPath: modelPath,
      threads: threads,
      contextSize: contextSize,
      gpuLayers: 0,
    );
    if (!await _controller.isModelLoaded()) {
      throw StateError('Yükleme çağrısı bitti ama llama.cpp modeli yüklü göstermedi.');
    }
    activeContext = contextSize;
    debugPrint('ARES_MODEL: yükleme tamamlandı.');
  }

  /// Model yüklü değilse ve dosya cihazdaysa yükler. Başarılıysa true döner.
  /// Eşzamanlı çağrılar aynı yüklemeyi bekler; model dosyası yoksa false döner.
  Future<bool> ensureLoaded() {
    final running = _loadingFuture;
    if (running != null) return running;
    final future = _ensureLoadedInner();
    _loadingFuture = future;
    future.whenComplete(() => _loadingFuture = null);
    return future;
  }

  Future<bool> _ensureLoadedInner() async {
    if (_disposed) return false;
    _loading = true;
    try {
      if (await _controller.isModelLoaded()) return true;
      final path = await _storage.getModelPath();
      if (!await File(path).exists()) {
        lastError = 'Model dosyası cihazda yok.';
        return false;
      }
      Object? failure;
      for (final context in LocalModelConfig.contextFallbacks) {
        try {
          await loadModel(modelPath: path, contextSize: context);
          lastError = '';
          return true;
        } catch (error) {
          failure = error;
          debugPrint('ARES_MODEL: ctx=$context ile yükleme başarısız: $error');
        }
      }
      lastError = '$failure';
      return false;
    } catch (error) {
      lastError = '$error';
      return false;
    } finally {
      _loading = false;
    }
  }

  /// [instruction] metnini Qwen3 sohbet biçiminde modele verir, temizlenmiş cevabı döndürür.
  Future<String> generateText(
    String instruction, {
    int maxTokens = LocalModelConfig.maxTokens,
    double temperature = LocalModelConfig.temperature,
  }) {
    return _serial<String>(() => _generate(instruction, maxTokens, temperature));
  }

  Future<String> _generate(String instruction, int maxTokens, double temperature) async {
    if (_disposed) {
      throw StateError('ARES yerel model servisi kapatılmış.');
    }
    if (instruction.trim().isEmpty) {
      throw ArgumentError('İstek boş olamaz.');
    }
    if (!await _controller.isModelLoaded()) {
      throw StateError('Yerel model yüklenmemiş.');
    }

    final context = activeContext > 0 ? activeContext : LocalModelConfig.contextFallbacks.last;
    // Küçük bağlamda cevap uzunluğunu da küçült.
    final limit = context < 1024 ? (context ~/ 4) : maxTokens;
    final tokens = limit < maxTokens ? limit : maxTokens;
    final prompt = _promptBuilder.build(instruction, contextTokens: context, maxTokens: tokens);

    final output = StringBuffer();
    try {
      await for (final token in _controller
          .generate(prompt: prompt, maxTokens: tokens, temperature: temperature)
          .timeout(LocalModelConfig.tokenTimeout)) {
        output.write(token);
      }
    } on TimeoutException {
      try {
        await _controller.stop();
      } catch (_) {
        // Durdurma başarısız olsa da zaman aşımı hatası bildirilir.
      }
      throw StateError('Yerel model zamanında cevap vermedi.');
    }
    return _cleaner.clean(output.toString());
  }

  Future<T> _serial<T>(Future<T> Function() task) {
    final next = _tail.then((_) => task());
    _tail = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  Future<void> stop() async {
    if (_disposed) return;
    await _controller.stop();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _controller.dispose();
  }
}
