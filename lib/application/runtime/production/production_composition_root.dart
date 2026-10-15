import '../../codegen/code_generation_orchestrator.dart';
import '../../content/content_generation_orchestrator.dart';
import '../../content/content_request_service.dart';
import '../../content/content_generation_runtime_module.dart';
import '../../codegen/code_generation_request_service.dart';
import '../../codegen/code_generation_runtime_module.dart';
import '../../config/runtime_config.dart';
import 'production_runtime.dart';
import 'runtime_module_registry.dart';
import 'operational_runtime_module.dart';

/// Composes the ARES production runtime modules and their dependencies.
class ProductionCompositionRoot {
  ProductionCompositionRoot({
    RuntimeConfig? config,
    CodeGenerationOrchestrator? codeGenerationOrchestrator,
    ContentGenerationOrchestrator? contentGenerationOrchestrator,
  })  : config = config ?? const RuntimeConfig(),
        _codeGenerationOrchestrator = codeGenerationOrchestrator,
        _contentGenerationOrchestrator = contentGenerationOrchestrator;

  final RuntimeConfig config;
  final CodeGenerationOrchestrator? _codeGenerationOrchestrator;
  final ContentGenerationOrchestrator? _contentGenerationOrchestrator;
  CodeGenerationRuntimeModule? _codeGenerationRuntimeModule;
  ContentGenerationRuntimeModule? _contentGenerationRuntimeModule;

  ProductionRuntime build() {
    final registry = RuntimeModuleRegistry();
    registry.register(OperationalRuntimeModule('Task Runtime'));
    registry.register(OperationalRuntimeModule('Agent Runtime'));
    registry.register(OperationalRuntimeModule('CEO Runtime'));
    registry.register(OperationalRuntimeModule('CIO Runtime'));
    registry.register(OperationalRuntimeModule('AI Gateway Runtime'));
    registry.register(OperationalRuntimeModule('Tool Gateway Runtime'));
    registry.register(OperationalRuntimeModule('Event Bus Runtime'));
    registry.register(OperationalRuntimeModule('Scheduler Runtime'));
    registry.register(OperationalRuntimeModule('Workflow Runtime'));
    registry.register(OperationalRuntimeModule('Android Runtime'));
    registry.register(OperationalRuntimeModule('Voice Runtime'));
    registry.register(OperationalRuntimeModule('Chat Runtime'));

    final orchestrator = _codeGenerationOrchestrator;
    if (orchestrator != null) {
      final module = CodeGenerationRuntimeModule(orchestrator);
      _codeGenerationRuntimeModule = module;
      registry.register(module);
    }

    final contentOrchestrator = _contentGenerationOrchestrator;
    if (contentOrchestrator != null) {
      final module = ContentGenerationRuntimeModule(contentOrchestrator);
      _contentGenerationRuntimeModule = module;
      registry.register(module);
    }

    registry.register(OperationalRuntimeModule('UI Projection Runtime'));
    return ProductionRuntime(config: config, modules: registry);
  }

  CodeGenerationRequestService buildCodeGenerationRequestService() {
    final orchestrator = _codeGenerationOrchestrator;
    if (orchestrator == null) {
      throw StateError('Code Generation Orchestrator verilmedi.');
    }
    build();
    final module = _codeGenerationRuntimeModule!;
    return CodeGenerationRequestService(runtimeModule: module);
  }

  ContentRequestService buildContentRequestService() {
    final orchestrator = _contentGenerationOrchestrator;
    if (orchestrator == null) {
      throw StateError('Content Generation Orchestrator verilmedi.');
    }
    build();
    return ContentRequestService(_contentGenerationRuntimeModule!);
  }
}
