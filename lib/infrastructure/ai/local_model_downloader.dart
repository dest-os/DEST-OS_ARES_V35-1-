import 'dart:async';
import 'dart:io';

import 'local_model_config.dart';
import 'local_model_storage.dart';

/// GGUF modelini geçici dosyaya indirir ve doğrulamadan sonra yerine taşır.
class LocalModelDownloader {
  LocalModelDownloader({
    LocalModelStorage? storage,
    HttpClient? httpClient,
  })  : _storage = storage ?? LocalModelStorage(),
        _httpClient = httpClient ?? (HttpClient()..connectionTimeout = const Duration(seconds: 20));

  final LocalModelStorage _storage;
  final HttpClient _httpClient;

  bool _isDownloading = false;
  bool _disposed = false;

  bool get isDownloading => _isDownloading;

  Future<String> downloadModel({
    void Function(double? progress)? onProgress,
    void Function(int receivedBytes, int totalBytes)? onBytes,
  }) async {
    if (_disposed) {
      throw StateError('İndirme servisi kapatılmış.');
    }
    if (_isDownloading) {
      throw StateError('Model indirme işlemi zaten devam ediyor.');
    }

    final uri = Uri.tryParse(LocalModelConfig.downloadUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw ArgumentError('Model HTTPS adresi geçerli değil.');
    }

    _isDownloading = true;
    File? temporaryFile;
    File? backupFile;
    var originalModelMoved = false;

    try {
      final finalPath = await _storage.getModelPath();
      final finalFile = File(finalPath);
      temporaryFile = File('$finalPath.part');
      backupFile = File('$finalPath.backup');

      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }

      if (await backupFile.exists()) {
        throw FileSystemException(
          'Model yedeği bulundu; otomatik silinmedi.',
          backupFile.path,
        );
      }

      final request = await _httpClient.getUrl(uri);
      request.followRedirects = true;
      request.maxRedirects = 5;
      request.headers.set(HttpHeaders.userAgentHeader, 'ARES/0.1 (Android)');

      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException(
          'Model indirilemedi. HTTP: ${response.statusCode}',
          uri: uri,
        );
      }

      final totalBytes = response.contentLength;
      var receivedBytes = 0;
      final sink = temporaryFile.openWrite();

      try {
        // 60 saniye boyunca veri gelmezse indirme zaman aşımıyla kesilir.
        await for (final chunk in response.timeout(const Duration(seconds: 60))) {
          sink.add(chunk);
          receivedBytes += chunk.length;

          final knownTotal = totalBytes > 0 ? totalBytes : LocalModelConfig.approxSizeBytes;
          onBytes?.call(receivedBytes, knownTotal);
          onProgress?.call((receivedBytes / knownTotal).clamp(0.0, totalBytes > 0 ? 1.0 : 0.99));
        }

        await sink.flush();
      } finally {
        await sink.close();
      }

      if (receivedBytes == 0) {
        throw const HttpException('İndirilen dosya boş.');
      }

      if (totalBytes > 0 && receivedBytes != totalBytes) {
        throw const HttpException('İndirme eksik tamamlandı.');
      }

      final handle = await temporaryFile.open();
      List<int> header;

      try {
        header = await handle.read(4);
      } finally {
        await handle.close();
      }

      if (header.length != 4 ||
          header[0] != 0x47 ||
          header[1] != 0x47 ||
          header[2] != 0x55 ||
          header[3] != 0x46) {
        throw const FormatException(
          'İndirilen dosya GGUF imzası taşımıyor.',
        );
      }

      final expectedSize = LocalModelConfig.expectedSizeBytes;
      if (expectedSize > 0 && receivedBytes != expectedSize) {
        throw HttpException(
          'Dosya boyutu beklenen değerle uyuşmuyor. '
          'Beklenen: $expectedSize, gelen: $receivedBytes',
        );
      }

      if (await finalFile.exists()) {
        await finalFile.rename(backupFile.path);
        originalModelMoved = true;
      }

      try {
        await temporaryFile.rename(finalFile.path);
      } catch (_) {
        if (originalModelMoved &&
            await backupFile.exists() &&
            !await finalFile.exists()) {
          await backupFile.rename(finalFile.path);
          originalModelMoved = false;
        }
        rethrow;
      }

      if (originalModelMoved && await backupFile.exists()) {
        await backupFile.delete();
        originalModelMoved = false;
      }

      onProgress?.call(1.0);
      return finalFile.path;
    } catch (_) {
      if (temporaryFile != null && await temporaryFile.exists()) {
        await temporaryFile.delete();
      }

      if (originalModelMoved &&
          backupFile != null &&
          await backupFile.exists()) {
        final finalPath = await _storage.getModelPath();
        final finalFile = File(finalPath);

        if (!await finalFile.exists()) {
          await backupFile.rename(finalPath);
        }
      }

      rethrow;
    } finally {
      _isDownloading = false;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _httpClient.close(force: true);
  }
}
