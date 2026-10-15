import '../../application/ai/ai_gateway.dart';
import '../../core/result/ares_result.dart';
import '../../domain/ai/ai_request.dart';
import '../../domain/ai/ai_response.dart';
import '../ai/local_model_config.dart';
import '../ai/local_model_service.dart';
import '../ai/local_model_storage.dart';

/// ARES içine gömülü llama.cpp motoru için ağ geçidi.
///
/// Ollama veya başka bir sunucu gerektirmez. Model dosyası cihazdaysa ama
/// henüz belleğe yüklenmediyse otomatik yüklenir.
class EmbeddedLocalAiGatewayAdapter implements AresAiGateway {
  EmbeddedLocalAiGatewayAdapter({
    required LocalModelService service,
    LocalModelStorage? storage,
  })  : _service = service,
        _storage = storage ?? LocalModelStorage();

  final LocalModelService _service;
  final LocalModelStorage _storage;

  @override
  Future<AresResult<AiResponse>> generate(AiRequest request) async {
    try {
      if (request.instruction.trim().isEmpty) {
        return const AresFailure<AiResponse>('Yerel AI isteği boş olamaz.');
      }

      var loaded = await _service.isModelLoaded;
      if (!loaded) {
        if (!await _storage.isModelAvailable()) {
          return const AresFailure<AiResponse>(
            'Yerel yapay zekâ modeli cihazda yok. Ayarlar > Genel AI Ayarları bölümünde '
            '"İndir ve yükle" düğmesine basın (yaklaşık 430 MB).',
          );
        }
        loaded = await _service.ensureLoaded();
        if (!loaded) {
          return AresFailure<AiResponse>(
            'Yerel yapay zekâ modeli yüklenemedi: ${_service.lastError.isEmpty ? 'bilinmeyen hata' : _service.lastError}',
          );
        }
      }

      final text = await _service.generateText(request.instruction);
      if (text.isEmpty) {
        return const AresFailure<AiResponse>('Yerel AI boş cevap üretti.');
      }
      return AresSuccess<AiResponse>(AiResponse(text: text, modelName: LocalModelConfig.fileName));
    } catch (error) {
      return AresFailure<AiResponse>('Gömülü yerel AI hatası: $error');
    }
  }
}
