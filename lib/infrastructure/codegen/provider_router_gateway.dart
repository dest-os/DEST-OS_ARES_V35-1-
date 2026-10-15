import '../../application/ai/ai_gateway.dart';
import '../../application/office/approval_store.dart';
import '../../application/office/office_hub.dart';
import '../../application/office/provider_store.dart';
import '../../core/result/ares_result.dart';
import '../../core/security/cost_policy.dart';
import '../../domain/ai/ai_request.dart';
import '../../domain/ai/ai_response.dart';
import '../../domain/office/ai_provider.dart';
import '../ai/local_model_service.dart';
import 'embedded_local_ai_gateway_adapter.dart';
import 'free_remote_ai_gateway_adapter.dart';
import 'local_ai_gateway_adapter.dart';
import 'openai_compatible_transport.dart';

/// Etkin yapay zekâları Model Sıralaması'na göre dener.
///
/// - Kotası dolan sağlayıcı atlanır ve sıradaki sağlayıcı denenir.
/// - Ücretli sağlayıcı kullanıcı onayı olmadan çağrılmaz.
/// - ares_embedded_local kimliği gömülü llama.cpp motorunu kullanır.
class ProviderRouterGateway implements AresAiGateway {
  ProviderRouterGateway({
    required this.providers,
    required this.approvals,
    this.hub,
    this.transport,
    LocalModelService? localModelService,
  }) : _localModelService = localModelService;

  static const String embeddedLocalProviderId = 'ares_embedded_local';

  final ProviderStore providers;
  final ApprovalStore approvals;
  final OfficeHub? hub;

  /// Testlerde sahte HTTP vermek için.
  final AiHttpTransport? transport;

  /// Gömülü yerel motor servisi.
  final LocalModelService? _localModelService;

  /// Son başarılı cevabı veren sağlayıcının adı.
  String lastProviderName = '';

  static const String noProviderMessage =
      'Kullanılabilir yapay zekâ yok. Ayarlar > AI Kataloğu bölümünden bir sağlayıcıyı etkinleştirip adres, model ve (gerekiyorsa) API anahtarını girin.';

  @override
  Future<AresResult<AiResponse>> generate(AiRequest request) =>
      generateFor(request);

  /// [preferredId] verilirse önce o sağlayıcı denenir.
  Future<AresResult<AiResponse>> generateFor(
    AiRequest request, {
    String? preferredId,
  }) async {
    final candidates = <AiProviderConfig>[...providers.callable];

    if (preferredId != null) {
      final index = candidates.indexWhere((p) => p.id == preferredId);
      if (index > 0) {
        final preferred = candidates.removeAt(index);
        candidates.insert(0, preferred);
      }
    }

    if (candidates.isEmpty) {
      return const AresFailure<AiResponse>(noProviderMessage);
    }

    final notes = <String>[];

    for (final p in candidates) {
      if (p.statusAt(providers.today) == ProviderStatus.limitReached) {
        notes.add('${p.name}: günlük kota doldu.');
        continue;
      }

      if (!p.configured) {
        notes.add('${p.name}: adres, model veya API anahtarı eksik.');
        continue;
      }

      if (p.category == ProviderCategory.paid && !p.paidApproved) {
        final created = await approvals.request(
          kind: 'paid_ai',
          title: 'Ücretli AI kullanım onayı: ${p.name}',
          detail:
              '${p.name} ücretlidir. Onaylarsanız istekler bu servise gönderilir ve hesabınızdan ücret kesilebilir.',
          refId: p.id,
        );

        if (created) {
          hub?.notify(
            'Ücretli AI kullanımı için onay bekliyor: ${p.name}',
            level: 'warn',
          );
        }

        notes.add('${p.name}: ücretli, kullanıcı onayı bekleniyor.');
        continue;
      }

      final AresAiGateway adapter = _adapterFor(p);

      final result = await adapter.generate(
        AiRequest(
          instruction: request.instruction,
          costClass: _costClassOf(p),
        ),
      );

      if (result is AresSuccess<AiResponse>) {
        lastProviderName = p.name;
        await providers.recordUse(p.id);
        return result;
      }

      if (result is AresFailure<AiResponse>) {
        notes.add('${p.name}: ${result.message}');

        if (_isQuotaError(result.message)) {
          await providers.markLimit(p.id);
          hub?.notify(
            '${p.name} kotası doldu; iş sıradaki yapay zekâya devredildi.',
            level: 'warn',
          );
        }
      }
    }

    return AresFailure<AiResponse>(
      'Hiçbir yapay zekâ cevap veremedi:\n- ${notes.join('\n- ')}',
    );
  }

  /// Tek bir sağlayıcıyı yedekleme ve sıralama olmadan dener.
  /// Kullanım sayacına işlenmez; ücretli sağlayıcı onaysız çağrılmaz.
  Future<AresResult<AiResponse>> testProvider(
    AiProviderConfig p,
  ) async {
    if (!p.chat) {
      return const AresFailure<AiResponse>(
        'Bu sağlayıcı sohbet için kullanılamaz (araç AI).',
      );
    }

    if (!p.configured) {
      return AresFailure<AiResponse>(
        '${p.name}: adres, model veya API anahtarı eksik.',
      );
    }

    if (p.category == ProviderCategory.paid && !p.paidApproved) {
      return AresFailure<AiResponse>(
        '${p.name} ücretli; test için önce Ayarlar > Onaylar bölümünden onay verin.',
      );
    }

    final AresAiGateway adapter = _adapterFor(p);

    return adapter.generate(
      const AiRequest(
        instruction: 'Sadece "tamam" yaz.',
        costClass: AiCostClass.free,
      ),
    );
  }

  AresAiGateway _adapterFor(AiProviderConfig p) {
    if (p.category == ProviderCategory.local) {
      if (p.id == embeddedLocalProviderId) {
        final service = _localModelService;

        if (service == null) {
          return _UnavailableEmbeddedLocalGateway();
        }

        return EmbeddedLocalAiGatewayAdapter(service: service);
      }

      // Diğer yerel sağlayıcılar Ollama/LM Studio HTTP adaptörünü kullanır.
      return LocalAiGatewayAdapter(
        baseUrl: p.baseUrl,
        model: p.model,
        transport: transport,
      );
    }

    return FreeRemoteAiGatewayAdapter(
      baseUrl: p.baseUrl,
      model: p.model,
      apiKey: p.hasKey ? p.apiKey : null,
      transport: transport,
    );
  }

  AiCostClass _costClassOf(AiProviderConfig p) {
    switch (p.category) {
      case ProviderCategory.local:
        return AiCostClass.local;
      case ProviderCategory.free:
        return AiCostClass.free;
      case ProviderCategory.paid:
        return AiCostClass.paid;
      case ProviderCategory.limitedFree:
      case ProviderCategory.tool:
      case ProviderCategory.other:
        return AiCostClass.limitedFree;
    }
  }

  bool _isQuotaError(String message) {
    final m = message.toLowerCase();

    return m.contains('http 429') ||
        m.contains('http 402') ||
        m.contains('quota') ||
        m.contains('rate limit') ||
        m.contains('too many requests') ||
        m.contains('kota');
  }
}

/// Servis henüz ana yönetime bağlanmamışsa güvenli hata döndürür.
class _UnavailableEmbeddedLocalGateway implements AresAiGateway {
  @override
  Future<AresResult<AiResponse>> generate(AiRequest request) async {
    return const AresFailure<AiResponse>(
      'Gömülü yerel AI servisi ana yönetime bağlanmamış. '
      'Model yükleme bağlantısı tamamlanmalıdır.',
    );
  }
}
