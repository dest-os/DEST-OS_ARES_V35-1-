import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../lib/application/settings/ares_settings.dart';
import '../../../lib/core/result/ares_result.dart';
import '../../../lib/core/security/cost_policy.dart';
import '../../../lib/domain/ai/ai_request.dart';
import '../../../lib/domain/ai/ai_response.dart';
import '../../../lib/infrastructure/codegen/dynamic_ares_ai_gateway.dart';
import '../../../lib/infrastructure/codegen/openai_compatible_transport.dart';
import '../../../lib/infrastructure/storage/json_file_store.dart';

class _FakeTransport implements AiHttpTransport {
  Uri? lastUri;
  Map<String, String>? lastHeaders;

  @override
  Future<AiHttpResponse> postJson({
    required Uri uri,
    required Map<String, String> headers,
    required Map<String, Object?> body,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    lastUri = uri;
    lastHeaders = headers;
    return const AiHttpResponse(statusCode: 200, body: '{"model":"m1","choices":[{"message":{"content":"tamam"}}]}');
  }

  @override
  Future<AiHttpResponse> getJson({
    required Uri uri,
    required Map<String, String> headers,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    return const AiHttpResponse(statusCode: 200, body: '{"data":[]}');
  }
}

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('ares_settings_'));
  tearDown(() => temp.deleteSync(recursive: true));

  AresSettingsStore store() => AresSettingsStore(store: JsonFileStore(directoryProvider: () async => temp));

  test('ayarlar kaydedilir ve yeniden açılışta okunur', () async {
    final first = store();
    await first.save(const AresSettings(freeBaseUrl: 'https://x.test/v1', freeModel: 'm1', freeApiKey: 'k-123456'));
    final second = store();
    await second.load();
    expect(second.current.freeBaseUrl, 'https://x.test/v1');
    expect(second.current.freeModel, 'm1');
    expect(second.current.freeApiKey, 'k-123456');
    expect(second.current.localEnabled, isFalse);
  });

  test('ayar yoksa anlaşılır hata verir', () async {
    final gateway = DynamicAresAiGateway(settings: store(), transport: _FakeTransport());
    final result = await gateway.generate(const AiRequest(instruction: 'selam', costClass: AiCostClass.free));
    expect(result, isA<AresFailure<AiResponse>>());
    expect((result as AresFailure<AiResponse>).message, contains('Ayarlar'));
  });

  test('uzak sağlayıcı ayarlıysa anahtarla istek atılır', () async {
    final s = store();
    await s.save(const AresSettings(freeBaseUrl: 'https://x.test/v1', freeModel: 'm1', freeApiKey: 'k-123456'));
    final transport = _FakeTransport();
    final gateway = DynamicAresAiGateway(settings: s, transport: transport);
    final result = await gateway.generate(const AiRequest(instruction: 'selam', costClass: AiCostClass.free));
    expect(result, isA<AresSuccess<AiResponse>>());
    expect((result as AresSuccess<AiResponse>).value.text, 'tamam');
    expect(transport.lastUri.toString(), 'https://x.test/v1/chat/completions');
    expect(transport.lastHeaders!['Authorization'], 'Bearer k-123456');
  });

  test('ücretli maliyet sınıfı otomatik açılmaz', () async {
    final s = store();
    await s.save(const AresSettings(freeBaseUrl: 'https://x.test/v1', freeModel: 'm1'));
    final gateway = DynamicAresAiGateway(settings: s, transport: _FakeTransport());
    final result = await gateway.generate(const AiRequest(instruction: 'selam', costClass: AiCostClass.paid));
    expect(result, isA<AresFailure<AiResponse>>());
  });
}
