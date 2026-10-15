import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Minimal HTTP transport used by OpenAI-compatible local/free AI adapters.
abstract interface class AiHttpTransport {
  /// Sends a JSON POST request and returns status code plus response text.
  Future<AiHttpResponse> postJson({
    required Uri uri,
    required Map<String, String> headers,
    required Map<String, Object?> body,
    Duration timeout = const Duration(seconds: 90),
  });

  /// Sends a GET request (ör. /v1/models listesi).
  Future<AiHttpResponse> getJson({
    required Uri uri,
    required Map<String, String> headers,
    Duration timeout = const Duration(seconds: 30),
  });
}

/// HTTP response returned by [AiHttpTransport].
class AiHttpResponse {
  /// Creates an immutable HTTP response.
  const AiHttpResponse({required this.statusCode, required this.body});

  /// HTTP status code.
  final int statusCode;

  /// Raw response body.
  final String body;
}

/// Production transport backed by Dart's [HttpClient].
class DartIoAiHttpTransport implements AiHttpTransport {
  /// Creates the production HTTP transport.
  const DartIoAiHttpTransport();

  @override
  Future<AiHttpResponse> postJson({
    required Uri uri,
    required Map<String, String> headers,
    required Map<String, Object?> body,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri).timeout(timeout);
      request.headers.contentType = ContentType.json;
      headers.forEach(request.headers.set);
      request.write(jsonEncode(body));
      final response = await request.close().timeout(timeout);
      final responseBody = await response.transform(utf8.decoder).join().timeout(timeout);
      return AiHttpResponse(statusCode: response.statusCode, body: responseBody);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<AiHttpResponse> getJson({
    required Uri uri,
    required Map<String, String> headers,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      headers.forEach(request.headers.set);
      final response = await request.close().timeout(timeout);
      final responseBody = await response.transform(utf8.decoder).join().timeout(timeout);
      return AiHttpResponse(statusCode: response.statusCode, body: responseBody);
    } finally {
      client.close(force: true);
    }
  }
}

/// OpenAI uyumlu /v1/models listesini çeker.
class RemoteModelCatalog {
  RemoteModelCatalog({AiHttpTransport? transport})
      : _transport = transport ?? const DartIoAiHttpTransport();

  final AiHttpTransport _transport;

  /// [baseUrl] ör. https://api.groq.com/openai/v1
  /// Dönüş: model id listesi (alfabetik).
  Future<List<String>> listModels({
    required String baseUrl,
    String? apiKey,
  }) async {
    final uri = _modelsUri(baseUrl);
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    final key = apiKey?.trim();
    if (key != null && key.isNotEmpty) {
      headers['Authorization'] = 'Bearer $key';
    }

    final response = await _transport.getJson(uri: uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Model listesi alınamadı (HTTP ${response.statusCode}).');
    }

    final decoded = jsonDecode(response.body);
    final ids = <String>[];
    if (decoded is Map && decoded['data'] is List) {
      for (final item in decoded['data'] as List) {
        if (item is Map && item['id'] is String) {
          final id = (item['id'] as String).trim();
          if (id.isNotEmpty) ids.add(id);
        }
      }
    } else if (decoded is List) {
      for (final item in decoded) {
        if (item is Map && item['id'] is String) {
          ids.add((item['id'] as String).trim());
        } else if (item is String && item.trim().isNotEmpty) {
          ids.add(item.trim());
        }
      }
    }
    ids.sort();
    return ids;
  }

  Uri _modelsUri(String raw) {
    final value = raw.trim().replaceFirst(RegExp(r'/+$'), '');
    if (value.endsWith('/models')) return Uri.parse(value);
    if (value.endsWith('/chat/completions')) {
      return Uri.parse(value.replaceFirst(RegExp(r'/chat/completions$'), '/models'));
    }
    if (value.endsWith('/v1')) return Uri.parse('$value/models');
    if (value.contains('/v1/')) {
      final base = value.split('/v1/').first;
      return Uri.parse('$base/v1/models');
    }
    return Uri.parse('$value/v1/models');
  }
}
