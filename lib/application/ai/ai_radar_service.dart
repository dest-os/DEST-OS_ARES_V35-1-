import '../../domain/ai/ai_model_profile.dart';
import 'ai_registry_repository.dart';

class AiRadarService {
  final AiRegistryRepository registry;

  const AiRadarService({required this.registry});

  List<AiModelProfile> scanRegistry() => registry.getAll();

  List<AiModelProfile> modelsRequiringApproval() => registry
      .getAll()
      .where((model) => model.requiresApproval)
      .toList(growable: false);

  List<AiModelProfile> verifiedModels() => registry
      .getAll()
      .where((model) => model.verificationStatus.name == 'verified')
      .toList(growable: false);
}
