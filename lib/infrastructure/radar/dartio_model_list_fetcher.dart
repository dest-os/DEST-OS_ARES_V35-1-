import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../application/radar/model_list_fetcher.dart';

/// dart:io ile model listesi sorgular.
class DartIoModelListFetcher implements ModelListFetcher {
  const DartIoModelListFetcher();

  static const Duration _timeout = Duration(seconds: 15);

  /// Sohbet adresinden /models adresini üretir.
  static Uri modelsUri(String baseUrl) {
    var root = baseUrl.trim();
    const suffix = '/chat/completions';
    if (root.endsWith(suffix)) {
      root = root.substring(0, root.length - suffix.length);
    }
    while (root.endsWith('/')) {
      root = root.substring(0, root.length - 1);
    }
    if (root.endsWith('/v1') || root.endsWith('/openai')) {
      return Uri.parse('$root/models');
    }
    return Uri.parse('$root/v1/models');
  }

  @override
  Future<List<String>> fetchModels({required String baseUrl, String apiKey = ''}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(modelsUri(baseUrl)).timeout(_timeout);
      if (apiKey.trim().isNotEmpty) {
        request.headers.set('Authorization', 'Bearer ${apiKey.trim()}');
      }
      final response = await request.close().timeout(_timeout);
      final body = await response.transform(utf8.decoder).join().timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(body);
      final ids = <String>[];
      if (decoded is Map) {
        final data = decoded['data'] ?? decoded['models'];
        if (data is List) {
          for (final item in data) {
            if (item is Map) {
              final id = item['id'] ?? item['name'];
              if (id is String && id.isNotEmpty) ids.add(id);
            }
          }
        }
      }
      return ids;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<bool> isReachable(String url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.parse(url)).timeout(_timeout);
      final response = await request.close().timeout(_timeout);
      await response.drain<void>();
      return response.statusCode < 500;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
